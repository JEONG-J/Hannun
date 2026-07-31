//
//  FetchCategoryBreakdownUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("FetchCategoryBreakdownUseCase")
struct FetchCategoryBreakdownUseCaseTests {
    private let exchangeRate = ExchangeRate(krwPerUSD: 1_300)

    private func useCase(holdings: [HoldingRecord]) -> FetchCategoryBreakdownUseCase {
        FetchCategoryBreakdownUseCase(
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: InMemoryHoldingRepository(holdings),
                    marketDataService: FixedPriceMarketDataService()
                )
            )
        )
    }

    @Test("자산군 비중의 합은 1 이다")
    func weightsSumToOne() async throws {
        let breakdown = try await useCase(holdings: [
            SampleRecords.holding(category: .cash, name: "현금", quantity: 2_500_000),
            SampleRecords.holding(
                category: .crypto,
                name: "비트코인",
                ticker: "KRW-BTC",
                quantity: 1,
                averagePrice: 7_500_000
            ),
        ]).execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        let cash = try #require(breakdown.first { $0.category == .cash })
        let crypto = try #require(breakdown.first { $0.category == .crypto })

        #expect(cash.weight * 100 == 25)
        #expect(crypto.weight * 100 == 75)
        #expect(breakdown.reduce(Decimal.zero) { $0 + $1.weight } == 1)
    }

    @Test("총자산이 0 이면 모든 비중이 0 이다")
    func avoidsDivisionByZero() async throws {
        let breakdown = try await useCase(holdings: [])
            .execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        #expect(breakdown.count == AssetCategory.allCases.count)
        #expect(breakdown.allSatisfy { $0.weight == 0 })
    }
}
