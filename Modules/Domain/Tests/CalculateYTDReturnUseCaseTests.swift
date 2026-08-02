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
        let rate = try #require(
            CalculateYTDReturnUseCase.rate(
                opening: opening,
                closing: closing,
                netCashFlow: netCashFlow
            )
        )

        #expect(rate * 100 == expectedPercent)
    }

    @Test("연초 자산이 0 이면 수익률을 내지 않는다")
    func rejectsZeroOpeningBalance() {
        #expect(CalculateYTDReturnUseCase.rate(opening: 0, closing: 1_000, netCashFlow: 0) == nil)
    }

    @Test("연초 스냅샷과 현재 자산, 입출금을 모아 수익률을 낸다")
    func combinesSnapshotAndCashFlow() async throws {
        let useCase = makeUseCase(
            snapshots: [
                SampleRecords.snapshot(
                    recordedOn: SampleRecords.day(2026, 1, 1),
                    totalInKRW: 100_000_000
                ),
            ],
            cashFlows: [
                SampleRecords.cashFlow(
                    occurredOn: SampleRecords.day(2026, 3, 2),
                    amount: 10_000_000,
                    kind: .deposit
                ),
            ],
            currentTotalInKRW: 120_000_000
        )

        let result = try #require(await execute(useCase))

        #expect(result.openingBalance == .krw(100_000_000))
        #expect(result.closingBalance == .krw(120_000_000))
        #expect(result.netCashFlow == .krw(10_000_000))
        #expect(result.rate * 100 == 10)
    }

    @Test("출금은 순입출금을 음수로 만든다")
    func treatsWithdrawalAsNegative() async throws {
        let useCase = makeUseCase(
            snapshots: [
                SampleRecords.snapshot(
                    recordedOn: SampleRecords.day(2026, 1, 1),
                    totalInKRW: 100_000_000
                ),
            ],
            cashFlows: [
                SampleRecords.cashFlow(
                    occurredOn: SampleRecords.day(2026, 4, 10),
                    amount: 5_000_000,
                    kind: .withdrawal
                ),
            ],
            currentTotalInKRW: 90_000_000
        )

        let result = try #require(await execute(useCase))

        #expect(result.netCashFlow == .krw(-5_000_000))
        #expect(result.rate * 100 == -5)
    }

    // MARK: - 계산할 수 없는 상태

    @Test("연초 스냅샷이 없으면 실패가 아니라 결과 없음이다")
    func missingOpeningSnapshotYieldsNoResult() async throws {
        let useCase = makeUseCase()

        #expect(try await execute(useCase) == nil)
    }

    @Test("연초 자산이 0 이면 실패가 아니라 결과 없음이다")
    func zeroOpeningBalanceYieldsNoResult() async throws {
        let useCase = makeUseCase(
            snapshots: [
                SampleRecords.snapshot(recordedOn: SampleRecords.day(2026, 1, 1), totalInKRW: 0),
            ],
            currentTotalInKRW: 3_000_000
        )

        #expect(try await execute(useCase) == nil)
    }

    @Test("저장소가 실패하면 그대로 던진다")
    func propagatesRepositoryFailure() async {
        let useCase = makeUseCase(snapshotFailure: .persistence("스냅샷을 읽지 못했어요."))

        await #expect(throws: AppError.persistence("스냅샷을 읽지 못했어요.")) {
            try await execute(useCase)
        }
    }

    // MARK: - Function

    private func execute(_ useCase: CalculateYTDReturnUseCase) async throws -> YTDReturn? {
        try await useCase.execute(
            asOf: SampleRecords.day(2026, 7, 1),
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )
    }

    /// 기말자산은 현금 보유 하나로 만든다 — 시세 조회를 타지 않아 값이 그대로 총자산이 된다.
    private func makeUseCase(
        snapshots: [NetWorthRecord] = [],
        cashFlows: [CashFlowRecord] = [],
        currentTotalInKRW: Decimal = 0,
        snapshotFailure: AppError? = nil
    ) -> CalculateYTDReturnUseCase {
        CalculateYTDReturnUseCase(
            snapshotRepository: InMemorySnapshotRepository(
                snapshots,
                calendar: SampleRecords.utcCalendar,
                failure: snapshotFailure
            ),
            cashFlowRepository: InMemoryCashFlowRepository(cashFlows),
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: InMemoryHoldingRepository([
                        SampleRecords.holding(
                            category: .cash,
                            name: "현금",
                            quantity: currentTotalInKRW
                        ),
                    ]),
                    marketDataService: FixedPriceMarketDataService()
                )
            ),
            calendar: SampleRecords.utcCalendar
        )
    }
}
