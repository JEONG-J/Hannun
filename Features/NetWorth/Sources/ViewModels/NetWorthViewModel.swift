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
    case stale(since: Date)
}

@MainActor
@Observable
final class NetWorthViewModel {

    // MARK: - Property

    private(set) var summary: Loadable<NetWorthSummary> = .idle

    /// 기준 통화 (NW-2). 바뀌는 즉시 들고 있던 금액을 재환산한다 — 다시 불러올 때까지
    /// 이전 통화 숫자가 남아 있으면 토글이 먹지 않은 것처럼 보인다.
    ///
    /// 환율 조회 창구가 아직 없어 여기 쓰이는 환율은 고정값이다. 창구가 생기면
    /// 마지막으로 성공한 환율이 이 자리에 들어온다.
    var baseCurrency: Currency {
        get { storedBaseCurrency }
        set {
            guard newValue != storedBaseCurrency else { return }

            storedBaseCurrency = newValue
            if let current = summary.value {
                summary = .loaded(current.converted(to: newValue, using: exchangeRate))
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
    private let exchangeRate: ExchangeRate
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    // MARK: - Function

    init(
        fetchNetWorth: any FetchNetWorthUseCaseProtocol,
        fetchCategoryBreakdown: any FetchCategoryBreakdownUseCaseProtocol,
        fetchTrend: any FetchNetWorthTrendUseCaseProtocol,
        exchangeRate: ExchangeRate,
        baseCurrency: Currency = .krw,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchNetWorth = fetchNetWorth
        self.fetchCategoryBreakdown = fetchCategoryBreakdown
        self.fetchTrend = fetchTrend
        self.exchangeRate = exchangeRate
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
            exchangeRate: Constants.fallbackExchangeRate
        )
    }

    /// 총자산·카테고리 비중을 한 번에 채운다 (NW-1, NW-3).
    ///
    /// 이미 보여줄 값이 있으면 스켈레톤으로 되돌리지 않는다 — 통화를 토글할 때마다 화면이
    /// 비면 방금 재환산해 둔 금액이 도로 사라진다.
    func load() async {
        if summary.value == nil { summary = .loading }

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
            freshness = .fresh(refreshedAt)
        } catch {
            degrade(on: error)
        }
    }

    /// 갱신에 실패해도 마지막으로 성공한 값을 그대로 둔다 — 빈 화면 대신 배지로 알린다.
    /// 한 번도 성공한 적이 없을 때만 인라인 실패로 떨어뜨린다.
    private func degrade(on error: any Error) {
        switch freshness {
        case .unknown:
            summary = .failed(error as? AppError ?? .unknown(String(describing: error)))
        case let .fresh(lastSuccess), let .stale(lastSuccess):
            freshness = .stale(since: lastSuccess)
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
    /// 환율 조회 창구가 없는 동안 쓰는 고정 환율. 창구가 생기면 이 상수는 사라진다.
    static let fallbackExchangeRate = ExchangeRate(krwPerUSD: 1_300)
}
