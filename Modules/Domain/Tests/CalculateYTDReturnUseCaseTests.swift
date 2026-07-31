//
//  CalculateYTDReturnUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("CalculateYTDReturnUseCase")
struct CalculateYTDReturnUseCaseTests {
    private let exchangeRate = ExchangeRate(krwPerUSD: 1_300)

    /// 비교값은 부동소수 오차를 타지 않도록 퍼센트 정수로 둔다.
    @Test(
        "입출금을 제외한 수익률을 계산한다",
        arguments: [
            (Decimal(100_000_000), Decimal(120_000_000), Decimal(0), Decimal(20)),
            (Decimal(100_000_000), Decimal(120_000_000), Decimal(10_000_000), Decimal(10)),
            (Decimal(100_000_000), Decimal(90_000_000), Decimal(-5_000_000), Decimal(-5)),
        ]
    )
    func excludesCashFlow(
        opening: Decimal,
        closing: Decimal,
        netCashFlow: Decimal,
        expectedPercent: Decimal
    ) throws {
        let rate = try CalculateYTDReturnUseCase.rate(
            opening: opening,
            closing: closing,
            netCashFlow: netCashFlow
        )

        #expect(rate * 100 == expectedPercent)
    }

    @Test("연초 자산이 0 이면 계산을 거부한다")
    func rejectsZeroOpeningBalance() {
        #expect(throws: AppError.validation("연초 자산이 0이라 수익률을 계산할 수 없어요.")) {
            try CalculateYTDReturnUseCase.rate(opening: 0, closing: 1_000, netCashFlow: 0)
        }
    }

    @Test("연초 스냅샷과 현재 자산, 입출금을 모아 수익률을 낸다")
    func combinesSnapshotAndCashFlow() async throws {
        let holdings = InMemoryHoldingRepository([
            SampleRecords.holding(category: .cash, name: "현금", quantity: 120_000_000),
        ])
        let cashFlows = InMemoryCashFlowRepository([
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 3, 2),
                amount: 10_000_000,
                kind: .deposit
            ),
        ])
        let snapshots = InMemorySnapshotRepository([
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 1, 1),
                totalInKRW: 100_000_000
            ),
        ])
        let useCase = CalculateYTDReturnUseCase(
            snapshotRepository: snapshots,
            cashFlowRepository: cashFlows,
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: holdings,
                    marketDataService: FixedPriceMarketDataService()
                )
            ),
            calendar: SampleRecords.utcCalendar
        )

        let result = try await useCase.execute(
            asOf: SampleRecords.day(2026, 7, 1),
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(result.openingBalance == .krw(100_000_000))
        #expect(result.closingBalance == .krw(120_000_000))
        #expect(result.netCashFlow == .krw(10_000_000))
        #expect(result.rate * 100 == 10)
    }

    @Test("출금은 순입출금을 음수로 만든다")
    func treatsWithdrawalAsNegative() async throws {
        let holdings = InMemoryHoldingRepository([
            SampleRecords.holding(category: .cash, name: "현금", quantity: 90_000_000),
        ])
        let cashFlows = InMemoryCashFlowRepository([
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 4, 10),
                amount: 5_000_000,
                kind: .withdrawal
            ),
        ])
        let snapshots = InMemorySnapshotRepository([
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 1, 1),
                totalInKRW: 100_000_000
            ),
        ])
        let useCase = CalculateYTDReturnUseCase(
            snapshotRepository: snapshots,
            cashFlowRepository: cashFlows,
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: holdings,
                    marketDataService: FixedPriceMarketDataService()
                )
            ),
            calendar: SampleRecords.utcCalendar
        )

        let result = try await useCase.execute(
            asOf: SampleRecords.day(2026, 7, 1),
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(result.netCashFlow == .krw(-5_000_000))
        #expect(result.rate * 100 == -5)
    }

    @Test("연초 스냅샷이 없으면 계산하지 않는다")
    func requiresOpeningSnapshot() async {
        let useCase = CalculateYTDReturnUseCase(
            snapshotRepository: InMemorySnapshotRepository(),
            cashFlowRepository: InMemoryCashFlowRepository(),
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: InMemoryHoldingRepository(),
                    marketDataService: FixedPriceMarketDataService()
                )
            ),
            calendar: SampleRecords.utcCalendar
        )

        await #expect(throws: AppError.self) {
            try await useCase.execute(
                asOf: SampleRecords.day(2026, 7, 1),
                baseCurrency: .krw,
                exchangeRate: exchangeRate
            )
        }
    }
}
