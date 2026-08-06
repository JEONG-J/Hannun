//
//  PortfolioUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("SaveHoldingUseCase")
struct SaveHoldingUseCaseTests {
    @Test("종목명이 비면 저장하지 않는다")
    func rejectsEmptyName() {
        #expect(throws: AppError.validation("종목명을 입력해 주세요.")) {
            try SaveHoldingUseCase.validated(
                SampleRecords.holding(category: .cash, name: "   ", quantity: 100)
            )
        }
    }

    @Test("수량이 0 이하면 저장하지 않는다")
    func rejectsNonPositiveQuantity() {
        #expect(throws: AppError.validation("수량은 0보다 커야 해요.")) {
            try SaveHoldingUseCase.validated(
                SampleRecords.holding(category: .cash, name: "현금", quantity: 0)
            )
        }
    }

    @Test("현금이 아니면 티커와 평단가가 필요하다")
    func requiresTickerAndAveragePrice() {
        #expect(throws: AppError.validation("티커·종목코드를 입력해 주세요.")) {
            try SaveHoldingUseCase.validated(
                SampleRecords.holding(
                    category: .domesticStock,
                    name: "삼성전자",
                    quantity: 10,
                    averagePrice: 70_000
                )
            )
        }
        #expect(throws: AppError.validation("평단가를 입력해 주세요.")) {
            try SaveHoldingUseCase.validated(
                SampleRecords.holding(
                    category: .domesticStock,
                    name: "삼성전자",
                    ticker: "005930",
                    quantity: 10
                )
            )
        }
    }

    @Test("현금은 티커·평단가를 지운다")
    func normalizesCashHolding() throws {
        let normalized = try SaveHoldingUseCase.validated(
            SampleRecords.holding(
                category: .cash,
                name: " 비상금 ",
                ticker: "CASH",
                quantity: 1_000_000,
                averagePrice: 1,
                manualPrice: 1
            )
        )

        #expect(normalized.name == "비상금")
        #expect(normalized.ticker.isEmpty)
        #expect(normalized.averagePrice == nil)
        #expect(normalized.manualPrice == nil)
    }

    @Test("저장한 종목은 다시 조회된다")
    func persistsThroughRepository() async throws {
        let repository = InMemoryHoldingRepository()
        let useCase = SaveHoldingUseCase(holdingRepository: repository)
        let holding = SampleRecords.holding(
            category: .etf,
            name: "TIGER 미국S&P500",
            ticker: "360750",
            quantity: 30,
            averagePrice: 18_000
        )

        try await useCase.execute(holding)

        let stored = try #require(await repository.fetch(id: holding.id))
        #expect(stored.name == "TIGER 미국S&P500")
    }
}

@Suite("DeleteHoldingUseCase")
struct DeleteHoldingUseCaseTests {
    @Test("삭제한 종목은 목록에서 사라진다")
    func removesHolding() async throws {
        let holding = SampleRecords.holding(category: .cash, name: "현금", quantity: 100)
        let repository = InMemoryHoldingRepository([holding])

        try await DeleteHoldingUseCase(holdingRepository: repository).execute(id: holding.id)

        #expect(await repository.fetchAll().isEmpty)
    }
}

@Suite("ManageCashFlowUseCase")
struct ManageCashFlowUseCaseTests {
    @Test("금액이 0 이하면 저장하지 않는다")
    func rejectsNonPositiveAmount() {
        #expect(throws: AppError.validation("금액은 0보다 커야 해요.")) {
            try ManageCashFlowUseCase.validated(
                SampleRecords.cashFlow(
                    occurredOn: SampleRecords.day(2026, 3, 1),
                    amount: 0,
                    kind: .deposit
                )
            )
        }
    }

    @Test("입금과 출금은 반대 부호를 갖는다")
    func signsByKind() {
        let deposit = SampleRecords.cashFlow(
            occurredOn: SampleRecords.day(2026, 3, 1),
            amount: 1_000_000,
            kind: .deposit
        )
        let withdrawal = SampleRecords.cashFlow(
            occurredOn: SampleRecords.day(2026, 3, 1),
            amount: 1_000_000,
            kind: .withdrawal
        )

        #expect(deposit.signedAmount == 1_000_000)
        #expect(withdrawal.signedAmount == -1_000_000)
    }

    @Test("저장한 입출금을 발생일 순으로 돌려준다")
    func sortsByDate() async throws {
        let repository = InMemoryCashFlowRepository()
        let useCase = ManageCashFlowUseCase(cashFlowRepository: repository)

        try await useCase.save(
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 5, 1),
                amount: 2_000_000,
                kind: .withdrawal
            )
        )
        try await useCase.save(
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 3, 1),
                amount: 1_000_000,
                kind: .deposit
            )
        )

        let events = try await useCase.fetchAll()
        #expect(events.map(\.occurredOn) == [
            SampleRecords.day(2026, 3, 1),
            SampleRecords.day(2026, 5, 1),
        ])
    }
}

@Suite("FetchHoldingsUseCase")
struct FetchHoldingsUseCaseTests {
    private let exchangeRate = ExchangeRate(krwPerUSD: 1_300)

    @Test("자산군으로 거를 수 있다")
    func filtersByCategory() async throws {
        let useCase = FetchHoldingsUseCase(
            holdingRepository: InMemoryHoldingRepository([
                SampleRecords.holding(category: .cash, name: "현금", quantity: 100),
                SampleRecords.holding(
                    category: .crypto,
                    name: "비트코인",
                    ticker: "KRW-BTC",
                    quantity: 1,
                    averagePrice: 90_000_000
                ),
            ]),
            marketDataService: FixedPriceMarketDataService(
                prices: ["KRW-BTC": .krw(95_000_000)]
            )
        )

        let valuations = try await useCase.execute(
            category: .crypto,
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(valuations.count == 1)
        #expect(valuations.first?.marketValue == .krw(95_000_000))
    }

    @Test("평가손익과 수익률을 계산한다")
    func computesProfit() async throws {
        let useCase = FetchHoldingsUseCase(
            holdingRepository: InMemoryHoldingRepository([
                SampleRecords.holding(
                    category: .domesticStock,
                    name: "삼성전자",
                    ticker: "005930",
                    quantity: 10,
                    averagePrice: 70_000
                ),
            ]),
            marketDataService: FixedPriceMarketDataService(prices: ["005930": .krw(77_000)])
        )

        let valuation = try #require(
            await useCase.execute(
                category: nil,
                baseCurrency: .krw,
                exchangeRate: exchangeRate
            ).first
        )

        #expect(valuation.marketValue == .krw(770_000))
        #expect(valuation.costBasis == .krw(700_000))
        #expect(valuation.profit == .krw(70_000))
        #expect((valuation.returnRate ?? 0) * 100 == 10)
    }

    @Test("현금은 현재가와 원가가 없다")
    func skipsPricingForCash() async throws {
        let useCase = FetchHoldingsUseCase(
            holdingRepository: InMemoryHoldingRepository([
                SampleRecords.holding(category: .cash, name: "현금", quantity: 1_000_000),
            ]),
            marketDataService: FixedPriceMarketDataService()
        )

        let valuation = try #require(
            await useCase.execute(
                category: nil,
                baseCurrency: .krw,
                exchangeRate: exchangeRate
            ).first
        )

        #expect(valuation.currentPrice == nil)
        #expect(valuation.costBasis == nil)
        #expect(valuation.marketValue == .krw(1_000_000))
    }
}
