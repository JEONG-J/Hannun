//
//  PortfolioListViewModel.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 한 카테고리로 묶인 보유 종목 묶음.
struct PortfolioSection: Identifiable, Equatable {
    let category: AssetCategory
    let subtotal: Money
    let valuations: [HoldingValuation]

    var id: AssetCategory { category }
}

/// 행이 강조하는 지표. 행 우측을 탭할 때마다 순환한다.
///
/// 한 행에 네 숫자를 동시에 늘어놓으면 어느 열도 읽히지 않아, 주지표만 남기고 나머지는
/// 탭으로 바꿔 보게 한다.
enum HoldingMetric: CaseIterable {
    case returnRate
    case profit
    case currentPrice

    var next: HoldingMetric {
        let cases = Self.allCases
        let nextIndex = (cases.firstIndex(of: self).map { $0 + 1 } ?? 0) % cases.count
        return cases[nextIndex]
    }
}

/// 보유 종목 목록 화면 (PF-1, PF-4).
@MainActor
@Observable
final class PortfolioListViewModel {

    // MARK: - Property

    private let fetchHoldings: any FetchHoldingsUseCaseProtocol
    private let deleteHolding: any DeleteHoldingUseCaseProtocol
    private let exchangeRateService: any ExchangeRateServiceProtocol
    private let errorHandler: ErrorHandler

    private(set) var valuations: Loadable<[HoldingValuation]> = .idle
    private(set) var metric: HoldingMetric = .returnRate
    private(set) var lastLoadedAt: Date?
    private(set) var didLastRefreshFail = false

    var selectedCategory: AssetCategory?
    var alertPrompt: AlertPrompt?

    private var collapsedCategories: Set<AssetCategory> = []

    /// 선택된 카테고리만 남긴 뒤 카테고리별로 묶은 결과.
    var sections: [PortfolioSection] {
        guard let loaded = valuations.value else { return [] }

        let visible = loaded.filter {
            selectedCategory == nil || $0.holding.category == selectedCategory
        }

        return AssetCategory.allCases.compactMap { category in
            let items = visible
                .filter { $0.holding.category == category }
                .sorted { $0.marketValue.amount > $1.marketValue.amount }

            guard !items.isEmpty else { return nil }
            return PortfolioSection(category: category, subtotal: total(of: items), valuations: items)
        }
    }

    /// 요약 바가 쓰는 금액. 필터가 걸려 있으면 화면에 보이는 만큼만 더한다.
    var summaryAmount: Money {
        total(of: sections.flatMap(\.valuations))
    }

    var summaryTitle: String {
        guard let selectedCategory else { return Constants.totalSummaryTitle }
        return selectedCategory.title + Constants.summaryTitleSuffix
    }

    /// 평단가가 있는 종목만 모아 계산한 수익금. 현금뿐이면 nil.
    var summaryProfit: Money? {
        let items = sections.flatMap(\.valuations).filter { $0.costBasis != nil }
        guard !items.isEmpty else { return nil }

        let cost = items.reduce(Decimal.zero) { $0 + ($1.costBasis?.amount ?? 0) }
        let market = items.reduce(Decimal.zero) { $0 + $1.marketValue.amount }
        return Money(amount: market - cost, currency: ValuationSettings.baseCurrency)
    }

    var summaryReturnRate: Decimal? {
        let items = sections.flatMap(\.valuations).filter { $0.costBasis != nil }
        let cost = items.reduce(Decimal.zero) { $0 + ($1.costBasis?.amount ?? 0) }
        guard cost > 0 else { return nil }

        let market = items.reduce(Decimal.zero) { $0 + $1.marketValue.amount }
        return (market - cost) / cost
    }

    var hasHoldings: Bool {
        valuations.value?.isEmpty == false
    }

    /// 액세서리가 말하는 종목 수. 필터가 걸려 있으면 보이는 만큼만 센다 — 요약 바 금액과
    /// 같은 모수를 써야 두 숫자가 같은 이야기를 한다.
    var visibleHoldingCount: Int {
        sections.reduce(0) { $0 + $1.valuations.count }
    }

    /// 갱신 실패 배지를 띄울지.
    ///
    /// 조회가 통째로 실패한 경우뿐 아니라, 성공했더라도 낡은 시세로 평가한 종목이 섞여 있으면
    /// 참이다 — 시세는 종목마다 따로 실패하므로 목록 전체가 최신이라고 말할 수 없다.
    var hasStaleQuotes: Bool {
        if didLastRefreshFail { return true }
        return valuations.value?.contains { $0.priceFreshness.isStale } ?? false
    }

    // MARK: - Function

    init(
        fetchHoldings: any FetchHoldingsUseCaseProtocol,
        deleteHolding: any DeleteHoldingUseCaseProtocol,
        exchangeRateService: any ExchangeRateServiceProtocol,
        errorHandler: ErrorHandler
    ) {
        self.fetchHoldings = fetchHoldings
        self.deleteHolding = deleteHolding
        self.exchangeRateService = exchangeRateService
        self.errorHandler = errorHandler
    }

    /// 화면이 처음 붙을 때만 스켈레톤을 띄운다. 이후 재진입은 이미 있는 값을 그대로 쓴다.
    func load() async {
        guard case .idle = valuations else { return }

        valuations = .loading
        await reload()
    }

    func refresh() async {
        await reload()
    }

    func selectCategory(_ category: AssetCategory?) {
        selectedCategory = category
    }

    func cycleMetric() {
        metric = metric.next
    }

    func isExpanded(_ category: AssetCategory) -> Bool {
        !collapsedCategories.contains(category)
    }

    func setExpanded(_ isExpanded: Bool, for category: AssetCategory) {
        if isExpanded {
            collapsedCategories.remove(category)
        } else {
            collapsedCategories.insert(category)
        }
    }

    /// PF-4. 실제 삭제는 확인 다이얼로그를 거친 뒤에만 일어난다.
    func requestDelete(_ valuation: HoldingValuation) {
        let holding = valuation.holding

        alertPrompt = AlertPrompt(
            title: "\(holding.name) 삭제",
            message: Constants.deleteMessage,
            confirmTitle: "삭제",
            isDestructive: true,
            confirmAction: { [weak self] in
                Task { await self?.delete(id: holding.id) }
            }
        )
    }

    /// 다른 탭에서 넘어온 카테고리 요청을 필터에 반영한다 (NW-4).
    func apply(_ route: AppRoute?) {
        guard case .portfolio(let category) = route else { return }
        selectedCategory = category
    }

    /// 확인 다이얼로그가 승인한 뒤에만 불린다.
    func delete(id: UUID) async {
        do {
            try await deleteHolding.execute(id: id)
            await reload()
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: Constants.featureName,
                    action: "종목 삭제",
                    retryAction: { [weak self] in await self?.delete(id: id) }
                )
            )
        }
    }

    private func reload() async {
        let exchangeRate = await exchangeRateService.currentRate()

        do {
            let loaded = try await fetchHoldings.execute(
                category: nil,
                baseCurrency: ValuationSettings.baseCurrency,
                exchangeRate: exchangeRate
            )

            valuations = .loaded(loaded)
            lastLoadedAt = Date()
            didLastRefreshFail = false
        } catch {
            // 이미 그려 둔 값이 있으면 화면을 비우지 않는다. 갱신 실패는 배지로만 알린다.
            guard valuations.value == nil else {
                didLastRefreshFail = true
                return
            }

            valuations = .failed(AppError(narrowing: error))
        }
    }

    private func total(of valuations: [HoldingValuation]) -> Money {
        let amount = valuations.reduce(Decimal.zero) { $0 + $1.marketValue.amount }
        return Money(amount: amount, currency: ValuationSettings.baseCurrency)
    }
}

fileprivate enum Constants {
    static let featureName = "포트폴리오"
    static let totalSummaryTitle = "총 평가금액"
    static let summaryTitleSuffix = " 평가금액"
    static let deleteMessage = "보유 기록이 사라집니다. 되돌릴 수 없어요."
}
