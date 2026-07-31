//
//  NetWorthViewModel.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 화면이 들고 있는 시세가 얼마나 최근 것인지.
enum QuoteFreshness: Equatable, Sendable {
    /// 아직 한 번도 갱신하지 못했다.
    case unknown
    /// 마지막 갱신이 성공했다.
    case fresh(Date)
    /// 갱신에 실패해 그 이전 값을 그대로 쓰고 있다.
    ///
    /// 시세를 한 번도 받지 못한 종목(수동 입력가로 평가한 종목)이 섞여 있으면 기준 시각을
    /// 말할 수 없어 `since` 가 nil 이다.
    case stale(since: Date?)
}

@MainActor
@Observable
final class NetWorthViewModel {

    // MARK: - Property

    private(set) var summary: Loadable<NetWorthSummary> = .idle

    /// 기준 통화 (NW-2). 바뀌는 즉시 들고 있던 금액을 재환산한다 — 다시 불러올 때까지
    /// 이전 통화 숫자가 남아 있으면 토글이 먹지 않은 것처럼 보인다.
    ///
    /// 재환산에는 **마지막으로 불러올 때 쓴 환율**을 그대로 쓴다. 여기서 새로 조회하면
    /// 토글 한 번에 네트워크가 붙고, 화면에 있는 금액과 다른 환율로 계산될 수도 있다.
    var baseCurrency: Currency {
        get { storedBaseCurrency }
        set {
            guard newValue != storedBaseCurrency else { return }

            storedBaseCurrency = newValue
            if let current = summary.value, let latestExchangeRate {
                summary = .loaded(current.converted(to: newValue, using: latestExchangeRate))
            }
        }
    }

    /// 도넛에서 고른 섹터. 중앙 홀 표시가 이 값을 따라간다.
    var selectedCategory: AssetCategory?

    private var storedBaseCurrency: Currency

    private(set) var freshness: QuoteFreshness = .unknown

    private let fetchNetWorth: any FetchNetWorthUseCaseProtocol
    private let fetchCategoryBreakdown: any FetchCategoryBreakdownUseCaseProtocol
    private let fetchTrend: any FetchNetWorthTrendUseCaseProtocol
    private let exchangeRateService: any ExchangeRateServiceProtocol
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    /// 마지막으로 불러올 때 쓴 환율. 통화 토글이 같은 값으로 되돌아올 수 있게 남겨 둔다.
    private var latestExchangeRate: ExchangeRate?

    // MARK: - Function

    init(
        fetchNetWorth: any FetchNetWorthUseCaseProtocol,
        fetchCategoryBreakdown: any FetchCategoryBreakdownUseCaseProtocol,
        fetchTrend: any FetchNetWorthTrendUseCaseProtocol,
        exchangeRateService: any ExchangeRateServiceProtocol,
        baseCurrency: Currency = .krw,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchNetWorth = fetchNetWorth
        self.fetchCategoryBreakdown = fetchCategoryBreakdown
        self.fetchTrend = fetchTrend
        self.exchangeRateService = exchangeRateService
        self.storedBaseCurrency = baseCurrency
        self.calendar = calendar
        self.now = now
    }

    convenience init(container: DIContainer) {
        self.init(
            fetchNetWorth: container.resolve((any FetchNetWorthUseCaseProtocol).self),
            fetchCategoryBreakdown: container.resolve(
                (any FetchCategoryBreakdownUseCaseProtocol).self
            ),
            fetchTrend: container.resolve((any FetchNetWorthTrendUseCaseProtocol).self),
            exchangeRateService: container.resolve((any ExchangeRateServiceProtocol).self)
        )
    }

    /// 총자산·카테고리 비중을 한 번에 채운다 (NW-1, NW-3).
    ///
    /// 이미 보여줄 값이 있으면 스켈레톤으로 되돌리지 않는다 — 통화를 토글할 때마다 화면이
    /// 비면 방금 재환산해 둔 금액이 도로 사라진다.
    func load() async {
        if summary.value == nil { summary = .loading }

        let exchangeRate = await exchangeRateService.currentRate()
        latestExchangeRate = exchangeRate

        do {
            let netWorth = try await fetchNetWorth.execute(
                baseCurrency: baseCurrency,
                exchangeRate: exchangeRate
            )
            let breakdown = try await fetchCategoryBreakdown.execute(
                baseCurrency: baseCurrency,
                exchangeRate: exchangeRate
            )
            let refreshedAt = now()

            summary = .loaded(
                NetWorthSummary(
                    total: netWorth.total,
                    breakdown: breakdown,
                    holdingCount: netWorth.valuations.count,
                    dailyChange: await dailyChange(against: netWorth.total, asOf: refreshedAt)
                )
            )
            freshness = quoteFreshness(of: netWorth.valuations, refreshedAt: refreshedAt)
        } catch {
            degrade(on: error)
        }
    }

    /// 조회에 성공해도 종목마다 시세 사정이 다르다. 하나라도 낡은 값으로 평가했으면 배지를 띄운다.
    ///
    /// 기준 시각은 낡은 종목 중 **가장 오래된 것**이다 — "몇 분 전 기준"은 가장 불리한 종목을
    /// 말해야 사용자가 숫자를 과신하지 않는다.
    private func quoteFreshness(
        of valuations: [HoldingValuation],
        refreshedAt: Date
    ) -> QuoteFreshness {
        let staleValuations = valuations.filter { $0.priceFreshness.isStale }
        guard !staleValuations.isEmpty else { return .fresh(refreshedAt) }

        return .stale(since: staleValuations.compactMap(\.priceFreshness.staleSince).min())
    }

    /// 갱신에 실패해도 마지막으로 성공한 값을 그대로 둔다 — 빈 화면 대신 배지로 알린다.
    /// 한 번도 성공한 적이 없을 때만 인라인 실패로 떨어뜨린다.
    private func degrade(on error: any Error) {
        switch freshness {
        case .unknown:
            summary = .failed(AppError(narrowing: error))
        case let .fresh(lastSuccess):
            freshness = .stale(since: lastSuccess)
        case .stale:
            break
        }
    }

    /// 비교할 스냅샷이 없으면 변동 자체를 만들지 않는다 — 0% 로 적으면 "변동 없음" 이라는
    /// 없는 사실이 된다. 조회 실패도 같은 취급이다(보조 지표라 화면을 실패로 떨어뜨리지 않는다).
    private func dailyChange(against total: Money, asOf date: Date) async -> NetWorthChange? {
        let startOfToday = calendar.startOfDay(for: date)

        guard
            let windowStart = calendar.date(
                byAdding: .day,
                value: -Constants.previousSnapshotLookbackDays,
                to: startOfToday
            ),
            let points = try? await fetchTrend.execute(
                from: windowStart,
                to: date,
                granularity: .daily,
                baseCurrency: baseCurrency
            ),
            let previous = points.last(where: { $0.date < startOfToday }),
            previous.total.amount > 0
        else { return nil }

        let difference = total.amount - previous.total.amount

        return NetWorthChange(
            amount: Money(amount: difference, currency: total.currency),
            ratio: difference / previous.total.amount
        )
    }
}

fileprivate enum Constants {
    /// 주말·공휴일에는 스냅샷이 없어 직전 기록까지 거슬러 본다.
    static let previousSnapshotLookbackDays = 7
}
