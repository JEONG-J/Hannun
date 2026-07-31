//
//  CompareBenchmarkUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("CompareBenchmarkUseCase")
struct CompareBenchmarkUseCaseTests {
    private let exchangeRate = ExchangeRate(krwPerUSD: 1_300)
    private let startDate = SampleRecords.day(2026, 1, 1)
    private let endDate = SampleRecords.day(2026, 3, 1)

    private var snapshots: [NetWorthRecord] {
        [
            SampleRecords.snapshot(recordedOn: startDate, totalInKRW: 100_000_000),
            SampleRecords.snapshot(
                recordedOn: SampleRecords.day(2026, 2, 1),
                totalInKRW: 110_000_000
            ),
            SampleRecords.snapshot(recordedOn: endDate, totalInKRW: 120_000_000),
        ]
    }

    private var benchmarks: [BenchmarkRecord] {
        [
            SampleRecords.benchmark(recordedOn: startDate, index: .kospi, value: 2_500),
            SampleRecords.benchmark(recordedOn: endDate, index: .kospi, value: 2_750),
            SampleRecords.benchmark(recordedOn: startDate, index: .nasdaq, value: 20_000),
        ]
    }

    private func useCase(
        benchmarkFailure: AppError? = nil,
        cashFlows: [CashFlowRecord] = []
    ) -> CompareBenchmarkUseCase {
        CompareBenchmarkUseCase(
            snapshotRepository: InMemorySnapshotRepository(
                snapshots,
                calendar: SampleRecords.utcCalendar
            ),
            cashFlowRepository: InMemoryCashFlowRepository(cashFlows),
            benchmarkRepository: InMemoryBenchmarkRepository(
                benchmarks,
                failure: benchmarkFailure
            )
        )
    }

    @Test("내 수익률을 기간 첫날 대비 등락률로 만든다")
    func normalizesPortfolioReturn() async throws {
        let comparison = try await useCase().execute(
            from: startDate,
            to: endDate,
            indices: [.kospi],
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(comparison.portfolio.map { $0.rate * 100 } == [0, 10, 20])
    }

    @Test("입출금은 내 수익률에서 빠진다")
    func excludesCashFlowFromPortfolio() async throws {
        let comparison = try await useCase(cashFlows: [
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 2, 1),
                amount: 10_000_000,
                kind: .deposit
            ),
        ]).execute(
            from: startDate,
            to: endDate,
            indices: [.kospi],
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(comparison.portfolio.map { $0.rate * 100 } == [0, 0, 10])
    }

    @Test("지수도 같은 방식으로 등락률이 된다")
    func normalizesBenchmarkSeries() async throws {
        let comparison = try await useCase().execute(
            from: startDate,
            to: endDate,
            indices: [.kospi],
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        let kospi = try #require(comparison.benchmarks.first { $0.index == .kospi })
        #expect(kospi.points.map { $0.rate * 100 } == [0, 10])
    }

    @Test("점이 2개 미만인 지수는 결과에서 빠진다")
    func dropsSeriesWithoutEnoughPoints() async throws {
        let comparison = try await useCase().execute(
            from: startDate,
            to: endDate,
            indices: [.kospi, .nasdaq],
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(comparison.benchmarks.map(\.index) == [.kospi])
    }

    @Test("지수 조회가 실패해도 내 수익률은 남는다")
    func survivesBenchmarkFailure() async throws {
        let comparison = try await useCase(benchmarkFailure: .network("연결 실패")).execute(
            from: startDate,
            to: endDate,
            indices: [.kospi],
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )

        #expect(comparison.benchmarks.isEmpty)
        #expect(comparison.portfolio.count == 3)
    }
}
