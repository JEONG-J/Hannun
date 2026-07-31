//
//  FetchNetWorthUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("FetchNetWorthUseCase")
struct FetchNetWorthUseCaseTests {
    private let exchangeRate = ExchangeRate(krwPerUSD: 1_300)

    private func useCase(
        holdings: [HoldingRecord],
        prices: [String: Money] = [:]
    ) -> FetchNetWorthUseCase {
        FetchNetWorthUseCase(
            fetchHoldingsUseCase: FetchHoldingsUseCase(
                holdingRepository: InMemoryHoldingRepository(holdings),
                marketDataService: FixedPriceMarketDataService(prices: prices)
            )
        )
    }

    @Test("달러 자산을 기준 통화로 환산해 합산한다")
    func convertsForeignHoldings() async throws {
        let useCase = useCase(
            holdings: [
                SampleRecords.holding(category: .cash, name: "원화 현금", quantity: 1_000_000),
                SampleRecords.holding(
                    category: .overseasStock,
                    name: "Apple",
                    ticker: "AAPL",
                    currency: .usd,
                    quantity: 10,
                    averagePrice: 150
                ),
            ],
            prices: ["AAPL": .usd(200)]
        )

        let netWorth = try await useCase.execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        // 1,000,000원 + 10주 × $200 × 1,300
        #expect(netWorth.total == .krw(3_600_000))
    }

    @Test("기준 통화를 달러로 바꾸면 원화 자산이 환산된다")
    func supportsUSDBaseCurrency() async throws {
        let useCase = useCase(
            holdings: [
                SampleRecords.holding(category: .cash, name: "원화 현금", quantity: 1_300_000),
            ]
        )

        let netWorth = try await useCase.execute(baseCurrency: .usd, exchangeRate: exchangeRate)

        #expect(netWorth.total == .usd(1_000))
    }

    @Test("자산군별 소계를 합산한다")
    func aggregatesCategorySubtotals() async throws {
        let useCase = useCase(
            holdings: [
                SampleRecords.holding(category: .cash, name: "현금", quantity: 1_000_000),
                SampleRecords.holding(
                    category: .domesticStock,
                    name: "삼성전자",
                    ticker: "005930",
                    quantity: 10,
                    averagePrice: 70_000
                ),
                SampleRecords.holding(
                    category: .domesticStock,
                    name: "SK하이닉스",
                    ticker: "000660",
                    quantity: 5,
                    averagePrice: 200_000
                ),
            ],
            prices: ["005930": .krw(80_000), "000660": .krw(220_000)]
        )

        let netWorth = try await useCase.execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        #expect(netWorth.subtotal(for: .cash) == .krw(1_000_000))
        #expect(netWorth.subtotal(for: .domesticStock) == .krw(1_900_000))
        #expect(netWorth.subtotal(for: .crypto) == .krw(0))
        #expect(netWorth.total == .krw(2_900_000))
    }

    @Test("소계 목록은 보유가 없는 자산군까지 5종을 모두 담는다")
    func keepsEmptyCategories() async throws {
        let useCase = useCase(holdings: [
            SampleRecords.holding(category: .cash, name: "현금", quantity: 500_000),
        ])

        let subtotals = try await useCase
            .execute(baseCurrency: .krw, exchangeRate: exchangeRate)
            .categorySubtotals

        #expect(subtotals.count == AssetCategory.allCases.count)
        #expect(subtotals.map(\.category) == AssetCategory.allCases)
    }

    @Test("보유가 없으면 총자산이 0 이다")
    func handlesEmptyPortfolio() async throws {
        let netWorth = try await useCase(holdings: [])
            .execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        #expect(netWorth.total == .krw(0))
        #expect(netWorth.valuations.isEmpty)
    }

    @Test("시세를 못 받으면 수동 입력가로 평가한다")
    func fallsBackToManualPrice() async throws {
        let useCase = FetchNetWorthUseCase(
            fetchHoldingsUseCase: FetchHoldingsUseCase(
                holdingRepository: InMemoryHoldingRepository([
                    SampleRecords.holding(
                        category: .etf,
                        name: "비상장 ETF",
                        ticker: "PRIVATE",
                        quantity: 10,
                        averagePrice: 1_000,
                        manualPrice: 1_500
                    ),
                ]),
                marketDataService: FixedPriceMarketDataService(
                    failure: .network("연결 실패")
                )
            )
        )

        let netWorth = try await useCase.execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        #expect(netWorth.total == .krw(15_000))
    }
}
