//
//  BenchmarkRepositoryTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunData
import HannunDomain
import HannunTestSupport
import Testing

@Suite("BenchmarkRepository")
struct BenchmarkRepositoryTests {
    private func makeRepository() throws -> BenchmarkRepository {
        BenchmarkRepository(modelContainer: try HannunModelContainer.make(inMemory: true))
    }

    private func fetchAll(
        _ repository: BenchmarkRepository,
        index: BenchmarkIndex
    ) async throws -> [BenchmarkRecord] {
        try await repository.fetch(
            index: index,
            from: SampleRecords.day(2026, 1, 1),
            to: SampleRecords.day(2026, 12, 31)
        )
    }

    @Test("지수별로 나눠 저장한다")
    func separatesByIndex() async throws {
        let repository = try makeRepository()
        try await repository.save([
            SampleRecords.benchmark(
                recordedOn: SampleRecords.day(2026, 3, 1),
                index: .kospi,
                value: 2_500
            ),
            SampleRecords.benchmark(
                recordedOn: SampleRecords.day(2026, 3, 1),
                index: .sp500,
                value: 5_800
            ),
        ])

        #expect(try await fetchAll(repository, index: .kospi).map(\.value) == [2_500])
        #expect(try await fetchAll(repository, index: .sp500).map(\.value) == [5_800])
        #expect(try await fetchAll(repository, index: .nasdaq).isEmpty)
    }

    @Test("같은 지수·같은 날짜는 덮어쓴다")
    func upsertsByIndexAndDay() async throws {
        let repository = try makeRepository()
        let day = SampleRecords.day(2026, 3, 1)

        try await repository.save([
            SampleRecords.benchmark(recordedOn: day, index: .kospi, value: 2_500),
        ])
        try await repository.save([
            SampleRecords.benchmark(recordedOn: day, index: .kospi, value: 2_600),
        ])

        #expect(try await fetchAll(repository, index: .kospi).map(\.value) == [2_600])
    }

    @Test("구간 조회는 날짜 오름차순이다")
    func sortsByDate() async throws {
        let repository = try makeRepository()
        try await repository.save([
            SampleRecords.benchmark(
                recordedOn: SampleRecords.day(2026, 3, 3),
                index: .bitcoin,
                value: 95_000
            ),
            SampleRecords.benchmark(
                recordedOn: SampleRecords.day(2026, 3, 1),
                index: .bitcoin,
                value: 90_000
            ),
        ])

        let records = try await repository.fetch(
            index: .bitcoin,
            from: SampleRecords.day(2026, 3, 1),
            to: SampleRecords.day(2026, 3, 2)
        )

        #expect(records.map(\.value) == [90_000])
    }
}
