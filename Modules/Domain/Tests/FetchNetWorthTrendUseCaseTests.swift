//
//  FetchNetWorthTrendUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("FetchNetWorthTrendUseCase")
struct FetchNetWorthTrendUseCaseTests {
    private let calendar = SampleRecords.utcCalendar

    private var storedSnapshots: [NetWorthRecord] {
        [
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 1, 1),
                totalInKRW: 100_000_000,
                totalInUSD: 76_923
            ),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 1, 20),
                totalInKRW: 105_000_000
            ),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 2, 3),
                totalInKRW: 110_000_000
            ),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 2, 25),
                totalInKRW: 115_000_000
            ),
        ]
    }

    private func useCase() -> FetchNetWorthTrendUseCase {
        FetchNetWorthTrendUseCase(
            snapshotRepository: InMemorySnapshotRepository(storedSnapshots, calendar: calendar),
            calendar: calendar
        )
    }

    @Test("일별 추이는 구간 안의 스냅샷을 그대로 쓴다")
    func returnsDailyPoints() async throws {
        let points = try await useCase().execute(
            from: SampleRecords.day(2026, 1, 1),
            to: SampleRecords.day(2026, 2, 28),
            granularity: .daily,
            baseCurrency: .krw
        )

        #expect(points.count == 4)
        #expect(points.first?.total == .krw(100_000_000))
        #expect(points.last?.total == .krw(115_000_000))
    }

    @Test("월별 추이는 각 달의 첫 스냅샷만 남긴다")
    func samplesFirstSnapshotOfEachMonth() async throws {
        let points = try await useCase().execute(
            from: SampleRecords.day(2026, 1, 1),
            to: SampleRecords.day(2026, 2, 28),
            granularity: .monthly,
            baseCurrency: .krw
        )

        #expect(points.map(\.date) == [
            SampleRecords.day(2026, 1, 1),
            SampleRecords.day(2026, 2, 3),
        ])
    }

    @Test("기준 통화에 맞는 금액을 돌려준다")
    func respectsBaseCurrency() async throws {
        let points = try await useCase().execute(
            from: SampleRecords.day(2026, 1, 1),
            to: SampleRecords.day(2026, 1, 1),
            granularity: .daily,
            baseCurrency: .usd
        )

        #expect(points.first?.total == .usd(76_923))
    }

    @Test("구간 밖 스냅샷은 빠진다")
    func excludesOutOfRange() async throws {
        let points = try await useCase().execute(
            from: SampleRecords.day(2026, 2, 1),
            to: SampleRecords.day(2026, 2, 28),
            granularity: .daily,
            baseCurrency: .krw
        )

        #expect(points.count == 2)
    }
}
