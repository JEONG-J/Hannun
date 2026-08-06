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

/// 카드 안 종목 행을 어떤 순서로 놓을지 (PF-1).
///
/// 카테고리 카드끼리의 순서는 여기서 바꾸지 않는다 — 순자산 탭 도넛 섹터와 같은 고정 순서라야
/// 같은 색이 두 화면에서 같은 자산을 가리킨다.
enum HoldingSortOrder: CaseIterable, Identifiable {
    case marketValue
    case returnRate
    case name

    /// 목록을 처음 여는 순서. 툴바가 "정렬을 건드렸는지" 를 이 값과 견주어 판단한다.
    static let initial: Self = .marketValue

    var id: Self { self }

    var title: String {
        switch self {
        case .marketValue: "평가금액순"
        case .returnRate: "수익률순"
        case .name: "가나다순"
        }
    }

    var symbolName: String {
        switch self {
        case .marketValue: "wonsign.circle"
        case .returnRate: "percent"
        case .name: "textformat"
        }
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

    /// 검색 시작 시점을 알아야 접힌 카드를 펼 수 있어서 `search(_:)` 로만 바꾼다.
    private(set) var searchText = ""

    /// 골라 둔 카테고리. 비어 있으면 전체를 보여 준다 — "아무것도 안 고름" 과 "전부 고름" 을
    /// 같은 화면으로 두어야 필터를 풀었을 때 종목이 하나도 없는 상태가 생기지 않는다.
    /// 바꾸는 길을 아래 함수들로 좁혀 두면 툴바 메뉴와 딥링크가 같은 규칙을 쓴다.
    private(set) var selectedCategories: Set<AssetCategory> = []

    var sortOrder: HoldingSortOrder = .initial
    var alertPrompt: AlertPrompt?

    private var collapsedCategories: Set<AssetCategory> = []

    /// 목록이 비었을 때 검색 때문인지 카테고리 필터 때문인지 갈라 말하려고 쓴다.
    var isSearching: Bool { !query.isEmpty }

    var isCategoryFiltered: Bool { !selectedCategories.isEmpty }

    /// 메뉴 라벨과 음성 안내가 이름을 늘어놓는 순서. `Set` 은 순회 순서가 실행마다 달라
    /// 그대로 쓰면 같은 선택이 매번 다르게 읽히므로, 카드·도넛과 같은 `allCases` 순서에
    /// 실어 고정한다.
    var selectedCategoryList: [AssetCategory] {
        AssetCategory.allCases.filter { selectedCategories.contains($0) }
    }

    /// 기본 순서를 벗어났는지. 정렬은 행 순서만 조용히 바꾸므로 메뉴를 열기 전에는 무엇으로
    /// 정렬 중인지 알 방법이 없다 — 툴바 아이콘이 이 값으로 그 사실을 대신 알린다.
    var isSortAdjusted: Bool { sortOrder != .initial }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 카테고리 필터와 검색어를 통과한 종목만 카테고리별로 묶은 결과.
    var sections: [PortfolioSection] {
        guard let loaded = valuations.value else { return [] }

        let visible = loaded.filter(isVisible)

        return AssetCategory.allCases.compactMap { category in
            let items = sorted(visible.filter { $0.holding.category == category })

            guard !items.isEmpty else { return nil }
            return PortfolioSection(category: category, subtotal: total(of: items), valuations: items)
        }
    }

    /// 요약 바가 쓰는 금액. 필터가 걸려 있으면 화면에 보이는 만큼만 더한다.
    var summaryAmount: Money {
        total(of: sections.flatMap(\.valuations))
    }

    /// 검색 중에는 "총" 이라고 말할 수 없다 — 요약 바가 더하는 건 걸러 낸 종목뿐이다.
    /// 카테고리를 여럿 고른 경우도 같은 이유로 "총" 을 못 쓰는데, 이름을 늘어놓으면 한 줄을
    /// 넘겨 버리므로 골라 놓았다는 사실만 말하고 어떤 것들인지는 툴바 메뉴 라벨에 맡긴다.
    var summaryTitle: String {
        if isSearching { return Constants.searchSummaryTitle }
        guard isCategoryFiltered else { return Constants.totalSummaryTitle }

        guard selectedCategories.count == 1, let onlyCategory = selectedCategories.first else {
            return Constants.filteredSummaryTitle
        }
        return onlyCategory.title + Constants.summaryTitleSuffix
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

    /// 이미 골라 둔 카테고리를 다시 누르면 그것만 뺀다. 마지막 하나까지 빼면 필터가 비어
    /// 전체 표시로 돌아가므로, 아무것도 안 보이는 상태에 갇히지 않는다.
    func toggleCategory(_ category: AssetCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func clearCategoryFilter() {
        selectedCategories.removeAll()
    }

    /// 하나만 남기는 선택. nil 이면 전체로 되돌린다.
    func selectCategory(_ category: AssetCategory?) {
        if let category {
            selectedCategories = [category]
        } else {
            clearCategoryFilter()
        }
    }

    func isCategorySelected(_ category: AssetCategory) -> Bool {
        selectedCategories.contains(category)
    }

    /// 검색을 시작하는 순간 접어 둔 카드를 전부 펼친다 — 찾은 종목이 접힌 카드 안에 숨으면
    /// 검색이 아무것도 못 찾은 것처럼 보인다.
    func search(_ text: String) {
        let wasIdle = !isSearching
        searchText = text

        if wasIdle, isSearching {
            collapsedCategories.removeAll()
        }
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
    ///
    /// "그 카테고리를 보여 달라" 가 아니라 "그 카테고리만 보여 달라" 는 요청이므로, 이미 골라
    /// 둔 것에 더하지 않고 통째로 갈아 끼운다.
    func apply(_ route: AppRoute?) {
        guard case .portfolio(let category) = route else { return }
        selectCategory(category)
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
            // 종목이 하나도 없으면 화면에서 검색창 자체가 사라진다. 검색어를 남겨 두면 다음에
            // 종목을 넣었을 때 보이지 않는 검색어가 그 종목을 걸러 낸다.
            if loaded.isEmpty { searchText = "" }
            lastLoadedAt = Date()
        } catch {
            // 갱신에 실패해도 마지막으로 그린 값은 그대로 둔다 — 읽고 있던 숫자를 지우고
            // 빈 화면을 들이미는 쪽이, 조금 낡은 값을 계속 보여 주는 쪽보다 나쁘다.
            guard valuations.value == nil else { return }

            valuations = .failed(AppError(narrowing: error))
        }
    }

    /// 티커도 함께 본다 — "삼성" 으로도 "005930" 으로도 같은 종목에 닿아야 하기 때문이다.
    private func isVisible(_ valuation: HoldingValuation) -> Bool {
        let holding = valuation.holding

        guard selectedCategories.isEmpty || selectedCategories.contains(holding.category) else {
            return false
        }
        guard !query.isEmpty else { return true }

        return holding.name.localizedStandardContains(query)
            || holding.ticker.localizedStandardContains(query)
    }

    private func sorted(_ items: [HoldingValuation]) -> [HoldingValuation] {
        switch sortOrder {
        case .marketValue:
            items.sorted { $0.marketValue.amount > $1.marketValue.amount }
        case .returnRate:
            items.sorted(by: hasHigherReturnRate)
        case .name:
            items.sorted {
                $0.holding.name.localizedStandardCompare($1.holding.name) == .orderedAscending
            }
        }
    }

    /// 수익률이 없는 현금은 0% 로 치지 않고 뒤로 보낸다 — 손실 종목 위에 놓이면
    /// "현금이 더 잘했다" 로 읽히는데, 애초에 비교 대상이 아니다.
    private func hasHigherReturnRate(_ lhs: HoldingValuation, _ rhs: HoldingValuation) -> Bool {
        switch (lhs.returnRate, rhs.returnRate) {
        case let (left?, right?):
            left > right
        case (nil, .some):
            false
        case (.some, nil):
            true
        case (nil, nil):
            lhs.marketValue.amount > rhs.marketValue.amount
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
    static let searchSummaryTitle = "검색 결과 평가금액"
    static let filteredSummaryTitle = "선택 카테고리 평가금액"
    static let summaryTitleSuffix = " 평가금액"
    static let deleteMessage = "보유 기록이 사라집니다. 되돌릴 수 없어요."
}
