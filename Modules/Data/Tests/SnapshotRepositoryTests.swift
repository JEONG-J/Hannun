//
//  SnapshotRepositoryTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunData
import HannunDomain
import HannunTestSupport
import Testing

@Suite("SnapshotRepository")
struct SnapshotRepositoryTests {
    private func makeRepository() throws -> SnapshotRepository {
        SnapshotRepository(modelContainer: try HannunModelContainer.make(inMemory: true))
    }

    @Test("스냅샷을 저장하고 다시 읽는다")
    func savesAndFetches() async throws {
        let repository = try makeRepository()
        let record = SampleRecords.snapshot(
            recordedOn: SampleRecords.day(2026, 3, 1),
            totalInKRW: 100_000_000,
            totalInUSD: 76_923,
            categorySubtotals: [
                CategorySubtotal(category: .cash, amount: 20_000_000),
                CategorySubtotal(category: .domesticStock, amount: 80_000_000),
            ]
        )

        try await repository.save([record])

        let stored = try #require(await repository.fetchAll().first)
        #expect(stored.totalInKRW == .krw(100_000_000))
        #expect(stored.totalInUSD == .usd(76_923))
        #expect(stored.categorySubtotals.count == 2)
    }

    @Test("같은 날짜를 다시 저장하면 덮어쓴다")
    func upsertsByDay() async throws {
        let repository = try makeRepository()
        let day = SampleRecords.day(2026, 3, 1)

        try await repository.save([
            SampleRecords.snapshot(recordedOn: day, totalInKRW: 100_000_000),
        ])
        try await repository.save([
            SampleRecords.snapshot(recordedOn: day, totalInKRW: 110_000_000),
        ])

        let stored = try await repository.fetchAll()
        #expect(stored.count == 1)
        #expect(stored.first?.totalInKRW == .krw(110_000_000))
    }

    @Test("가장 최근 스냅샷을 돌려준다")
    func returnsLatest() async throws {
        let repository = try makeRepository()
        try await repository.save([
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 1),
                totalInKRW: 100_000_000
            ),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 4),
                totalInKRW: 120_000_000
            ),
        ])

        #expect(try await repository.latest()?.totalInKRW == .krw(120_000_000))
    }

    @Test("기록이 없으면 최신 스냅샷도 없다")
    func returnsNilWhenEmpty() async throws {
        #expect(try await makeRepository().latest() == nil)
    }

    @Test("구간 조회는 날짜 오름차순이다")
    func fetchesSortedRange() async throws {
        let repository = try makeRepository()
        try await repository.save([
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 4),
                totalInKRW: 120_000_000
            ),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 3, 1),
                totalInKRW: 100_000_000
            ),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 4, 1),
                totalInKRW: 130_000_000
            ),
        ])

        let stored = try await repository.fetch(
            from: SampleRecords.day(2026, 3, 1),
            to: SampleRecords.day(2026, 3, 31)
        )

        #expect(stored.map(\.recordedOn) == [
            SampleRecords.day(2026, 3, 1),
            SampleRecords.day(2026, 3, 4),
        ])
    }
}
