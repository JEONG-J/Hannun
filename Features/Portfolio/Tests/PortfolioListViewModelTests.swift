//
//  PortfolioListViewModelTests.swift
//  PortfolioFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import HannunTestSupport
import Testing
@testable import PortfolioFeature

@MainActor
@Suite("보유 종목 목록")
struct PortfolioListViewModelTests {

    // MARK: - Property

    private let cashID = UUID()
    private let domesticID = UUID()
    private let overseasID = UUID()

    private var records: [HoldingRecord] {
        [
            SampleRecords.holding(
                id: cashID,
                category: .cash,
                name: "생활비 통장",
                quantity: 1_000_000
            ),
            SampleRecords.holding(
                id: domesticID,
                category: .domesticStock,
                name: "삼성전자",
                ticker: "005930",
                quantity: 10,
                averagePrice: 70_000
            ),
            SampleRecords.holding(
                id: overseasID,
                category: .overseasStock,
                name: "Apple",
                ticker: "AAPL",
                currency: .usd,
                quantity: 5,
                averagePrice: 150
            ),
        ]
    }

    private var prices: [String: Money] {
        ["005930": .krw(80_000), "AAPL": .usd(200)]
    }

    /// 이름 오름차순과 수익률 내림차순이 서로 반대가 되도록 짠 한 카테고리짜리 표본.
    /// 정렬 기준이 실제로 바뀌었는지 한 배열로 확인할 수 있다.
    private var mixedReturnRecords: [HoldingRecord] {
        [
            SampleRecords.holding(
                category: .domesticStock,
                name: "손실",
                ticker: "000660",
                quantity: 10,
                averagePrice: 70_000
            ),
            SampleRecords.holding(
                category: .domesticStock,
                name: "이익",
                ticker: "005930",
                quantity: 1,
                averagePrice: 70_000
            ),
        ]
    }

    // MARK: - Function

    @Test("카테고리별로 묶고 소계를 더한다")
    func groupsByCategory() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()

        #expect(viewModel.sections.map(\.category) == [.cash, .domesticStock, .overseasStock])
        #expect(viewModel.sections[0].subtotal == .krw(1_000_000))
        #expect(viewModel.sections[1].subtotal == .krw(800_000))
        #expect(viewModel.sections[2].subtotal == .krw(1_380_000))
    }

    @Test("한 카테고리 안에서는 평가금액이 큰 종목이 먼저 온다")
    func sortsByMarketValueDescending() async {
        let holdings = [
            SampleRecords.holding(
                category: .domesticStock,
                name: "소액",
                ticker: "000660",
                quantity: 1,
                averagePrice: 100
            ),
            SampleRecords.holding(
                category: .domesticStock,
                name: "대액",
                ticker: "005930",
                quantity: 10,
                averagePrice: 70_000
            ),
        ]
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(holdings),
            prices: prices
        )

        await viewModel.load()

        #expect(viewModel.sections.first?.valuations.map(\.holding.name) == ["대액", "소액"])
    }

    @Test("정렬을 수익률순으로 바꾸면 수익률이 높은 종목이 먼저 온다")
    func sortsByReturnRateDescending() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(mixedReturnRecords),
            prices: ["005930": .krw(80_000), "000660": .krw(50_000)]
        )

        await viewModel.load()
        viewModel.sortOrder = .returnRate

        #expect(viewModel.sections.first?.valuations.map(\.holding.name) == ["이익", "손실"])
    }

    @Test("수익률순에서 수익률 없는 종목은 손실 종목보다도 뒤로 간다")
    func placesUnpricedHoldingsLastWhenSortingByReturnRate() async {
        let unpriced = SampleRecords.holding(
            category: .domesticStock,
            name: "평단미상",
            ticker: "035420",
            quantity: 2
        )
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(mixedReturnRecords + [unpriced]),
            prices: ["005930": .krw(80_000), "000660": .krw(50_000), "035420": .krw(90_000)]
        )

        await viewModel.load()
        viewModel.sortOrder = .returnRate

        let names = viewModel.sections.first?.valuations.map(\.holding.name)
        #expect(names == ["이익", "손실", "평단미상"])
    }

    @Test("정렬을 바꿔도 카테고리 카드 순서는 고정이다")
    func keepsCategoryOrderRegardlessOfSort() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()

        for order in HoldingSortOrder.allCases {
            viewModel.sortOrder = order
            #expect(viewModel.sections.map(\.category) == [.cash, .domesticStock, .overseasStock])
        }
    }

    @Test("정렬을 가나다순으로 바꾸면 이름 오름차순으로 온다")
    func sortsByName() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(mixedReturnRecords),
            prices: ["005930": .krw(80_000), "000660": .krw(50_000)]
        )

        await viewModel.load()
        viewModel.sortOrder = .name

        #expect(viewModel.sections.first?.valuations.map(\.holding.name) == ["손실", "이익"])
    }

    @Test("기본 순서를 벗어날 때만 정렬을 건드렸다고 본다")
    func marksSortAdjustedOutsideInitialOrder() {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository()
        )

        #expect(viewModel.sortOrder == .initial)
        #expect(viewModel.isSortAdjusted == false)

        viewModel.sortOrder = .returnRate
        #expect(viewModel.isSortAdjusted)

        viewModel.sortOrder = .initial
        #expect(viewModel.isSortAdjusted == false)
    }

    /// 검색창은 종목이 있을 때만 화면에 붙는다. 마지막 종목을 지운 뒤에도 검색어가 남아
    /// 있으면, 다음에 넣은 종목이 보이지 않는 검색어에 걸려 사라진다.
    @Test("마지막 종목이 사라지면 검색어도 함께 지운다")
    func clearsSearchWhenLastHoldingDisappears() async {
        let repository = InMemoryHoldingRepository(records)
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: repository,
            prices: prices
        )

        await viewModel.load()
        viewModel.search("삼성")
        #expect(viewModel.isSearching)

        for id in [cashID, domesticID, overseasID] {
            await viewModel.delete(id: id)
        }

        #expect(viewModel.hasHoldings == false)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test("검색어는 종목명과 티커를 모두 본다", arguments: ["삼성", "005930", "005"])
    func searchesNameAndTicker(_ keyword: String) async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.search(keyword)

        #expect(viewModel.isSearching)
        #expect(viewModel.sections.map(\.category) == [.domesticStock])
        #expect(viewModel.sections.first?.valuations.map(\.holding.name) == ["삼성전자"])
    }

    @Test("검색어는 대소문자를 가리지 않는다")
    func searchIgnoresCase() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.search("aapl")

        #expect(viewModel.sections.first?.valuations.map(\.holding.name) == ["Apple"])
    }

    @Test("공백만 넣은 검색어는 아무것도 거르지 않는다")
    func blankSearchKeepsEverything() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.search("   ")

        #expect(viewModel.isSearching == false)
        #expect(viewModel.summaryTitle == "순자산")
        #expect(viewModel.sections.map(\.category) == [.cash, .domesticStock, .overseasStock])
    }

    @Test("검색 중에는 요약이 걸러 낸 만큼만 센다")
    func summaryFollowsSearch() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.search("삼성")

        #expect(viewModel.summaryTitle == "검색 결과 평가금액")
        #expect(viewModel.summaryAmount == .krw(800_000))
        #expect(viewModel.visibleHoldingCount == 1)
    }

    @Test("검색을 시작하면 접어 둔 카드가 다시 펼쳐진다")
    func searchExpandsCollapsedSections() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.setExpanded(false, for: .domesticStock)
        #expect(!viewModel.isExpanded(.domesticStock))

        viewModel.search("삼성")
        #expect(viewModel.isExpanded(.domesticStock))

        // 검색을 이어 치는 동안에는 다시 접을 수 있어야 한다.
        viewModel.setExpanded(false, for: .domesticStock)
        viewModel.search("삼성전")
        #expect(!viewModel.isExpanded(.domesticStock))
    }

    @Test("현금은 평단가도 수익률도 없다")
    func cashHasNoCostBasis() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        let cash = viewModel.sections.first { $0.category == .cash }?.valuations.first

        #expect(cash?.costBasis == nil)
        #expect(cash?.returnRate == nil)
        #expect(cash?.currentPrice == nil)
    }

    @Test("요약은 전체 평가금액과 수익을 더한다")
    func summarizesEverything() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()

        #expect(viewModel.summaryTitle == "순자산")
        #expect(viewModel.summaryAmount == .krw(3_180_000))
        #expect(viewModel.summaryProfit == .krw(445_000))
    }

    @Test("필터를 걸면 요약도 보이는 만큼만 센다")
    func summaryFollowsFilter() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.selectCategory(.cash)

        #expect(viewModel.isCategoryFiltered)
        #expect(viewModel.selectedCategoryList == [.cash])
        #expect(viewModel.sections.map(\.category) == [.cash])
        #expect(viewModel.summaryTitle == "현금 평가금액")
        #expect(viewModel.summaryAmount == .krw(1_000_000))
        #expect(viewModel.summaryProfit == nil)
        #expect(viewModel.summaryReturnRate == nil)
    }

    @Test("고른 카테고리만 남기고 나머지는 걸러 낸다")
    func showsOnlySelectedCategories() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.toggleCategory(.domesticStock)
        viewModel.toggleCategory(.overseasStock)

        #expect(viewModel.isCategorySelected(.domesticStock))
        #expect(viewModel.isCategorySelected(.cash) == false)
        // 고른 순서가 아니라 카드·도넛과 같은 고정 순서로 나와야 칩이 제자리를 지킨다.
        #expect(viewModel.selectedCategoryList == [.domesticStock, .overseasStock])
        #expect(viewModel.sections.map(\.category) == [.domesticStock, .overseasStock])
        #expect(viewModel.summaryAmount == .krw(2_180_000))
        #expect(viewModel.visibleHoldingCount == 2)
    }

    @Test("같은 카테고리를 다시 누르면 선택이 풀린다")
    func togglesSameCategoryOff() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.toggleCategory(.cash)
        #expect(viewModel.sections.map(\.category) == [.cash])

        viewModel.toggleCategory(.cash)

        #expect(viewModel.isCategorySelected(.cash) == false)
        #expect(viewModel.isCategoryFiltered == false)
        #expect(viewModel.sections.map(\.category) == [.cash, .domesticStock, .overseasStock])
    }

    @Test("필터를 비우면 전체가 돌아온다")
    func clearingFilterRestoresEverything() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.toggleCategory(.cash)
        viewModel.toggleCategory(.etf)

        viewModel.clearCategoryFilter()

        #expect(viewModel.selectedCategories.isEmpty)
        #expect(viewModel.selectedCategoryList.isEmpty)
        #expect(viewModel.isCategoryFiltered == false)
        #expect(viewModel.summaryTitle == "순자산")
        #expect(viewModel.summaryAmount == .krw(3_180_000))
    }

    /// 카테고리를 여럿 고르면 이름을 늘어놓는 대신 골랐다는 사실만 말한다.
    @Test("두 개 이상 고르면 요약 제목이 선택 카테고리로 바뀐다")
    func summaryTitleGeneralizesAcrossCategories() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.toggleCategory(.cash)
        #expect(viewModel.summaryTitle == "현금 평가금액")

        viewModel.toggleCategory(.domesticStock)

        #expect(viewModel.summaryTitle == "선택 카테고리 평가금액")
        #expect(viewModel.summaryAmount == .krw(1_800_000))
    }

    /// 부채는 "평가" 하지 않는다 — 남은 원금이 곧 값이다.
    @Test("대출만 고르면 요약 제목이 대출 잔액이 된다")
    func namesLoanSummaryAsBalance() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        await viewModel.load()
        viewModel.toggleCategory(.loan)

        #expect(viewModel.summaryTitle == "대출 잔액")
    }

    @Test("지표는 수익률 → 수익금 → 현재가 순으로 돈다")
    func cyclesMetric() {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository()
        )

        #expect(viewModel.metric == .returnRate)

        viewModel.cycleMetric()
        #expect(viewModel.metric == .profit)

        viewModel.cycleMetric()
        #expect(viewModel.metric == .currentPrice)

        viewModel.cycleMetric()
        #expect(viewModel.metric == .returnRate)
    }

    @Test("카테고리를 접었다 다시 펼 수 있다")
    func togglesSectionExpansion() {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository()
        )

        #expect(viewModel.isExpanded(.crypto))

        viewModel.setExpanded(false, for: .crypto)
        #expect(!viewModel.isExpanded(.crypto))
        #expect(viewModel.isExpanded(.etf))

        viewModel.setExpanded(true, for: .crypto)
        #expect(viewModel.isExpanded(.crypto))
    }

    @Test("삭제 요청만으로는 지워지지 않는다")
    func deleteNeedsConfirmation() async throws {
        let repository = InMemoryHoldingRepository(records)
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: repository,
            prices: prices
        )

        await viewModel.load()
        let target = try #require(viewModel.sections.first?.valuations.first)
        viewModel.requestDelete(target)
        let remaining = await repository.fetchAll()

        #expect(viewModel.alertPrompt?.title == "생활비 통장 삭제")
        #expect(viewModel.alertPrompt?.isDestructive == true)
        #expect(remaining.count == 3)
    }

    @Test("확인한 뒤에는 목록에서 사라진다")
    func deletesAfterConfirmation() async {
        let repository = InMemoryHoldingRepository(records)
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: repository,
            prices: prices
        )

        await viewModel.load()
        await viewModel.delete(id: domesticID)
        let deleted = await repository.fetch(id: domesticID)

        #expect(deleted == nil)
        #expect(viewModel.sections.map(\.category) == [.cash, .overseasStock])
    }

    /// 딥링크는 "그 카테고리만" 이라는 뜻이라, 먼저 골라 둔 필터가 있어도 갈아 끼운다.
    @Test("다른 탭에서 넘어온 카테고리를 필터에 반영한다")
    func appliesIncomingRoute() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        viewModel.toggleCategory(.cash)
        viewModel.apply(.portfolio(category: .overseasStock))
        await viewModel.load()

        #expect(viewModel.selectedCategories == [.overseasStock])
        #expect(viewModel.sections.map(\.category) == [.overseasStock])
    }

    @Test("처음부터 조회에 실패하면 실패 상태로 남는다")
    func failsOnFirstLoad() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: FlakyHoldingRepository(records, successCount: 0)
        )

        await viewModel.load()

        #expect(viewModel.valuations.error != nil)
        #expect(viewModel.sections.isEmpty)
    }

    @Test("이미 그린 값이 있으면 갱신 실패에도 지우지 않는다")
    func keepsLastValueOnRefreshFailure() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: FlakyHoldingRepository(records, successCount: 1),
            prices: prices
        )

        await viewModel.load()
        #expect(viewModel.hasHoldings)

        await viewModel.refresh()

        #expect(viewModel.valuations.value?.count == 3)
    }
}
