//
//  PerformancePreviewData.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

#if DEBUG
import Foundation
import HannunCore
import HannunDomain

/// 프리뷰·테스트가 함께 쓰는 UseCase 스텁.
///
/// 결과를 클로저로 받아 호출 인자에 따라 다른 값을 돌려줄 수 있게 한다 — 기간·단위 전환이
/// 실제로 새 구간을 조회하는지 확인하려면 인자를 봐야 하기 때문이다.
struct StubCalculateYTDReturnUseCase: CalculateYTDReturnUseCaseProtocol {

    // MARK: - Property

    let result: @Sendable (Date) async throws -> YTDReturn

    // MARK: - Function

    init(result: @escaping @Sendable (Date) async throws -> YTDReturn) {
        self.result = result
    }

    func execute(
        asOf date: Date,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> YTDReturn {
        try await result(date)
    }
}

struct StubFetchNetWorthTrendUseCase: FetchNetWorthTrendUseCaseProtocol {

    // MARK: - Property

    let result: @Sendable (Date, Date, TrendGranularity) async throws -> [NetWorthTrendPoint]

    // MARK: - Function

    init(
        result: @escaping @Sendable (Date, Date, TrendGranularity) async throws
            -> [NetWorthTrendPoint]
    ) {
        self.result = result
    }

    func execute(
        from startDate: Date,
        to endDate: Date,
        granularity: TrendGranularity,
        baseCurrency: Currency
    ) async throws -> [NetWorthTrendPoint] {
        try await result(startDate, endDate, granularity)
    }
}

struct StubCompareBenchmarkUseCase: CompareBenchmarkUseCaseProtocol {

    // MARK: - Property

    let result: @Sendable (Date, Date, [BenchmarkIndex]) async throws -> BenchmarkComparison

    // MARK: - Function

    init(
        result: @escaping @Sendable (Date, Date, [BenchmarkIndex]) async throws
            -> BenchmarkComparison
    ) {
        self.result = result
    }

    func execute(
        from startDate: Date,
        to endDate: Date,
        indices: [BenchmarkIndex],
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> BenchmarkComparison {
        try await result(startDate, endDate, indices)
    }
}

/// 프리뷰용 표본. 2026년 1월 1일부터 26일 간격 8개 시점이다.
enum PerformanceSampleData {

    // MARK: - Property

    static let yearStart = Date(timeIntervalSince1970: 1_767_225_600)
    static let now = yearStart.addingTimeInterval(Constants.interval * 7)

    static let ytdReturn = YTDReturn(
        openingBalance: .krw(100_000_000),
        closingBalance: .krw(118_000_000),
        netCashFlow: .krw(8_600_000),
        rate: 0.094
    )

    static let trendPoints: [NetWorthTrendPoint] = portfolioRates.enumerated().map {
        NetWorthTrendPoint(
            date: date(at: $0.offset),
            total: .krw(Constants.openingTotal * (1 + $0.element))
        )
    }

    static let comparison = BenchmarkComparison(
        portfolio: points(of: portfolioRates),
        benchmarks: [
            BenchmarkSeries(index: .sp500, points: points(of: benchmarkRates)),
            BenchmarkSeries(index: .kospi, points: points(of: kospiRates)),
        ]
    )

    private static let portfolioRates: [Decimal] = [
        0, 0.012, 0.004, 0.031, 0.048, 0.042, 0.076, 0.094,
    ]
    private static let benchmarkRates: [Decimal] = [
        0, 0.008, 0.016, 0.011, 0.024, 0.036, 0.032, 0.051,
    ]
    private static let kospiRates: [Decimal] = [
        0, -0.004, 0.009, 0.018, 0.012, 0.027, 0.031, 0.038,
    ]

    // MARK: - Function

    static func date(at offset: Int) -> Date {
        yearStart.addingTimeInterval(Constants.interval * Double(offset))
    }

    private static func points(of rates: [Decimal]) -> [BenchmarkPoint] {
        rates.enumerated().map { BenchmarkPoint(date: date(at: $0.offset), rate: $0.element) }
    }
}

extension PerformanceViewModel {
    /// 프리뷰용 인스턴스. 화면이 `.task` 로 `loadIfNeeded()` 를 부르면 표본이 채워진다.
    @MainActor
    static var preview: PerformanceViewModel {
        let viewModel = PerformanceViewModel(
            calculateYTDReturnUseCase: StubCalculateYTDReturnUseCase { _ in
                PerformanceSampleData.ytdReturn
            },
            fetchNetWorthTrendUseCase: StubFetchNetWorthTrendUseCase { _, _, _ in
                PerformanceSampleData.trendPoints
            },
            compareBenchmarkUseCase: StubCompareBenchmarkUseCase { _, _, _ in
                PerformanceSampleData.comparison
            },
            now: { PerformanceSampleData.now }
        )
        viewModel.selectBenchmark(.sp500)
        return viewModel
    }
}

fileprivate enum Constants {
    /// 26일. 8개 점이 한 해를 고르게 덮는 간격이다.
    static let interval: TimeInterval = 60 * 60 * 24 * 26
    static let openingTotal: Decimal = 120_000_000
}
#endif
