//
//  CompareBenchmarkUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 비교 차트의 점 하나. 값이 아니라 기간 첫날 대비 등락률이라 축을 공유할 수 있다.
public struct BenchmarkPoint: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let date: Date

    /// 0.12 == 기준일 대비 +12%.
    public let rate: Decimal

    public var id: Date { date }

    // MARK: - Function

    public init(date: Date, rate: Decimal) {
        self.date = date
        self.rate = rate
    }
}

/// 지수 하나의 등락률 시계열.
public struct BenchmarkSeries: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let index: BenchmarkIndex
    public let points: [BenchmarkPoint]

    public var id: BenchmarkIndex { index }

    // MARK: - Function

    public init(index: BenchmarkIndex, points: [BenchmarkPoint]) {
        self.index = index
        self.points = points
    }
}

/// 내 수익률과 지수들의 등락률을 같은 기간으로 맞춘 비교 결과.
public struct BenchmarkComparison: Equatable, Sendable {
    // MARK: - Property

    public let portfolio: [BenchmarkPoint]
    public let benchmarks: [BenchmarkSeries]

    // MARK: - Function

    public init(portfolio: [BenchmarkPoint], benchmarks: [BenchmarkSeries]) {
        self.portfolio = portfolio
        self.benchmarks = benchmarks
    }
}

/// 내 수익률을 KOSPI·S&P 500·나스닥·비트코인과 나란히 놓는다.
public protocol CompareBenchmarkUseCaseProtocol: Sendable {
    /// 점이 2개 미만인 지수는 선을 그릴 수 없으므로 결과에서 빠진다.
    func execute(
        from startDate: Date,
        to endDate: Date,
        indices: [BenchmarkIndex],
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> BenchmarkComparison
}

public struct CompareBenchmarkUseCase: CompareBenchmarkUseCaseProtocol {
    // MARK: - Property

    private let snapshotRepository: any SnapshotRepositoryProtocol
    private let cashFlowRepository: any CashFlowRepositoryProtocol
    private let benchmarkRepository: any BenchmarkRepositoryProtocol

    // MARK: - Function

    public init(
        snapshotRepository: any SnapshotRepositoryProtocol,
        cashFlowRepository: any CashFlowRepositoryProtocol,
        benchmarkRepository: any BenchmarkRepositoryProtocol
    ) {
        self.snapshotRepository = snapshotRepository
        self.cashFlowRepository = cashFlowRepository
        self.benchmarkRepository = benchmarkRepository
    }

    public func execute(
        from startDate: Date,
        to endDate: Date,
        indices: [BenchmarkIndex],
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> BenchmarkComparison {
        let snapshots = try await snapshotRepository.fetch(from: startDate, to: endDate)
        let cashFlows = try await cashFlowRepository.fetch(from: startDate, to: endDate)

        var benchmarks: [BenchmarkSeries] = []
        for index in indices {
            let records = try? await benchmarkRepository.fetch(
                index: index,
                from: startDate,
                to: endDate
            )
            let points = Self.normalized(records ?? [])
            guard points.count >= 2 else { continue }
            benchmarks.append(BenchmarkSeries(index: index, points: points))
        }

        return BenchmarkComparison(
            portfolio: Self.portfolioPoints(
                snapshots: snapshots,
                cashFlows: cashFlows,
                baseCurrency: baseCurrency,
                exchangeRate: exchangeRate
            ),
            benchmarks: benchmarks
        )
    }

    /// 입출금은 성과가 아니므로 누적 순입출금을 빼고 등락률을 낸다.
    static func portfolioPoints(
        snapshots: [NetWorthRecord],
        cashFlows: [CashFlowRecord],
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) -> [BenchmarkPoint] {
        guard let opening = snapshots.first else { return [] }

        let openingAmount = opening.total(in: baseCurrency).amount
        guard openingAmount > 0 else { return [] }

        let flows = cashFlows
            .filter { $0.occurredOn > opening.recordedOn }
            .sorted { $0.occurredOn < $1.occurredOn }

        return snapshots.map { snapshot in
            let netCashFlow = flows
                .prefix { $0.occurredOn <= snapshot.recordedOn }
                .reduce(Decimal.zero) {
                    $0 + exchangeRate.convert($1.signedMoney, to: baseCurrency).amount
                }
            let closing = snapshot.total(in: baseCurrency).amount

            return BenchmarkPoint(
                date: snapshot.recordedOn,
                rate: (closing - openingAmount - netCashFlow) / openingAmount
            )
        }
    }

    static func normalized(_ records: [BenchmarkRecord]) -> [BenchmarkPoint] {
        guard let base = records.first, base.value > 0 else { return [] }

        return records.map {
            BenchmarkPoint(date: $0.recordedOn, rate: ($0.value - base.value) / base.value)
        }
    }
}
