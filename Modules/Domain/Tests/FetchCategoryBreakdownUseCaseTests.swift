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

    /// 분모가 순자산이면 대출이 낀 순간 자산군 합이 100% 를 넘는다.
    @Test("대출이 있어도 자산군 비중의 합은 1 이고 대출 비중은 0 이다")
    func excludesLiabilityFromWeights() async throws {
        let breakdown = try await useCase(holdings: [
            SampleRecords.holding(category: .cash, name: "현금", quantity: 4_000_000),
            SampleRecords.holding(
                category: .crypto,
                name: "비트코인",
                ticker: "KRW-BTC",
                quantity: 1,
                averagePrice: 6_000_000
            ),
            SampleRecords.holding(category: .loan, name: "신용대출", quantity: 3_000_000),
        ]).execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        let loan = try #require(breakdown.first { $0.category == .loan })
        let assetWeights = breakdown
            .filter { !$0.category.isLiability }
            .reduce(Decimal.zero) { $0 + $1.weight }

        #expect(loan.amount == .krw(-3_000_000))
        #expect(loan.weight == 0)
        #expect(assetWeights == 1)
    }

    @Test("대출만 있으면 0 으로 나누지 않고 비중이 전부 0 이다")
    func avoidsDivisionByZeroWithOnlyLiabilities() async throws {
        let breakdown = try await useCase(holdings: [
            SampleRecords.holding(category: .loan, name: "신용대출", quantity: 3_000_000),
        ]).execute(baseCurrency: .krw, exchangeRate: exchangeRate)

        #expect(breakdown.allSatisfy { $0.weight == 0 })
    }
}
