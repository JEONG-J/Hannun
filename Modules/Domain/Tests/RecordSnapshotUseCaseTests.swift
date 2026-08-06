//
//  RecordSnapshotUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("RecordSnapshotUseCase")
struct RecordSnapshotUseCaseTests {
    private let exchangeRate = ExchangeRate(krwPerUSD: 1_300)
    private let calendar = SampleRecords.utcCalendar

    @Test("마지막 기록과 오늘 사이의 빈 날을 직전 값으로 채운다")
    func backfillsMissingDays() {
        let latest = SampleRecords.snapshot(
            recordedOn: SampleRecords.day(2026, 3, 1),
            totalInKRW: 100_000_000
        )
        let current = SampleRecords.snapshot(
            recordedOn: SampleRecords.day(2026, 3, 5),
            totalInKRW: 110_000_000
        )

        let records = RecordSnapshotUseCase.backfilled(
            latest: latest,
            current: current,
            calendar: calendar
        )

        #expect(records.map(\.recordedOn) == [
            SampleRecords.day(2026, 3, 2),
            SampleRecords.day(2026, 3, 3),
            SampleRecords.day(2026, 3, 4),
            SampleRecords.day(2026, 3, 5),
        ])
        #expect(records.dropLast().allSatisfy { $0.totalInKRW == .krw(100_000_000) })
        #expect(records.last?.totalInKRW == .krw(110_000_000))
    }

    @Test("채운 날만 옮겨 적었다고 표시하고 오늘치는 실측으로 남긴다")
    func marksOnlyBackfilledDaysAsCarriedForward() {
        let records = RecordSnapshotUseCase.backfilled(
            latest: SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 1),
                totalInKRW: 100_000_000
            ),
            current: SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 5),
                totalInKRW: 110_000_000
            ),
            calendar: calendar
        )

        #expect(records.dropLast().allSatisfy { $0.isCarriedForward })
        #expect(records.last?.isCarriedForward == false)
    }

    @Test("어제 기록이 있으면 오늘치만 남긴다")
    func skipsBackfillWhenConsecutive() {
        let records = RecordSnapshotUseCase.backfilled(
            latest: SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 4),
                totalInKRW: 100_000_000
            ),
            current: SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 5),
                totalInKRW: 110_000_000
            ),
            calendar: calendar
        )

        #expect(records.count == 1)
        #expect(records.first?.recordedOn == SampleRecords.day(2026, 3, 5))
    }

    @Test("기록이 하나도 없으면 오늘치만 만든다")
    func startsFromToday() {
        let current = SampleRecords.snapshot(
            recordedOn: SampleRecords.day(2026, 3, 5),
            totalInKRW: 110_000_000
        )

        let records = RecordSnapshotUseCase.backfilled(
            latest: nil,
            current: current,
            calendar: calendar
        )

        #expect(records.count == 1)
        #expect(records.first?.totalInKRW == .krw(110_000_000))
    }

    @Test("같은 날 다시 기록해도 하루 한 건으로 유지된다")
    func keepsOneRecordPerDay() async throws {
        let snapshots = InMemorySnapshotRepository(calendar: calendar)
        let holdings = InMemoryHoldingRepository([
            SampleRecords.holding(category: .cash, name: "현금", quantity: 1_300_000),
        ])
        let useCase = RecordSnapshotUseCase(
            snapshotRepository: snapshots,
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: holdings,
                    marketDataService: FixedPriceMarketDataService()
                )
            ),
            calendar: calendar
        )

        let today = SampleRecords.day(2026, 3, 5)
        try await useCase.execute(asOf: today, exchangeRate: exchangeRate)
        try await useCase.execute(asOf: today, exchangeRate: exchangeRate)

        let stored = await snapshots.fetchAll()
        #expect(stored.count == 1)
        #expect(stored.first?.totalInKRW == .krw(1_300_000))
        #expect(stored.first?.totalInUSD == .usd(1_000))
    }

    @Test("스냅샷에 자산군 소계를 함께 남긴다")
    func storesCategorySubtotals() async throws {
        let snapshots = InMemorySnapshotRepository(calendar: calendar)
        let useCase = RecordSnapshotUseCase(
            snapshotRepository: snapshots,
            fetchNetWorthUseCase: FetchNetWorthUseCase(
                fetchHoldingsUseCase: FetchHoldingsUseCase(
                    holdingRepository: InMemoryHoldingRepository([
                        SampleRecords.holding(
                            category: .cash,
                            name: "현금",
                            quantity: 1_000_000
                        ),
                    ]),
                    marketDataService: FixedPriceMarketDataService()
                )
            ),
            calendar: calendar
        )

        let record = try await useCase.execute(
            asOf: SampleRecords.day(2026, 3, 5),
            exchangeRate: exchangeRate
        )

        let cash = try #require(record.categorySubtotals.first { $0.category == .cash })
        #expect(cash.amount == 1_000_000)
    }
}
