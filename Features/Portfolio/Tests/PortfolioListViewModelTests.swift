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

        #expect(viewModel.summaryTitle == "총 평가금액")
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

        #expect(viewModel.sections.map(\.category) == [.cash])
        #expect(viewModel.summaryTitle == "현금 평가금액")
        #expect(viewModel.summaryAmount == .krw(1_000_000))
        #expect(viewModel.summaryProfit == nil)
        #expect(viewModel.summaryReturnRate == nil)
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

    @Test("다른 탭에서 넘어온 카테고리를 필터에 반영한다")
    func appliesIncomingRoute() async {
        let viewModel = PortfolioTestFactory.listViewModel(
            repository: InMemoryHoldingRepository(records),
            prices: prices
        )

        viewModel.apply(.portfolio(category: .overseasStock))
        await viewModel.load()

        #expect(viewModel.selectedCategory == .overseasStock)
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

        #expect(viewModel.didLastRefreshFail)
        #expect(viewModel.valuations.value?.count == 3)
    }
}
