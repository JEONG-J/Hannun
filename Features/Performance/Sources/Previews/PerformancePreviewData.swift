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

    let result: @Sendable (Date) async throws -> YTDReturn?

    // MARK: - Function

    init(result: @escaping @Sendable (Date) async throws -> YTDReturn?) {
        self.result = result
    }

    func execute(
        asOf date: Date,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> YTDReturn? {
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

/// 환율을 고정해 프리뷰·테스트의 원화 환산 결과를 결정적으로 만든다.
struct StubExchangeRateService: ExchangeRateServiceProtocol {

    // MARK: - Property

    private let rate: ExchangeRate

    // MARK: - Function

    init(krwPerUSD: Decimal = 1_380) {
        rate = ExchangeRate(krwPerUSD: krwPerUSD)
    }

    func currentRate() async -> ExchangeRate { rate }
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

/// 캘린더 카드 전용 표본 — 2026년 7월 하루치 기록들.
///
/// `PerformanceSampleData` 는 26일 간격 8개 점이라 한 달 격자에 한 칸밖에 남지 않는다.
/// 캘린더가 실제로 무엇을 그리는지 보려면 일 단위 표본이 따로 필요하다.
///
/// 표본이 일부러 담고 있는 것:
/// - **6월 30일** — 7월 1일의 전일 총자산을 만드는 하루. 결과에서는 걸러져야 한다.
/// - **7일** — 전날과 누적 등락률이 같아 일간 수익률이 정확히 0% 인 날(`neutral`).
/// - **12~18일** — 통째로 비운 한 주. 기록 없는 주가 어떻게 그려지는지 본다.
enum PerformanceCalendarSampleData {

    // MARK: - Property

    /// 2026년 7월 1일 00:00 UTC.
    static let monthStart = Date(timeIntervalSince1970: 1_782_864_000)

    static let points: [NetWorthTrendPoint] = samples.map {
        NetWorthTrendPoint(
            date: date(offsetBy: $0.dayOffset),
            total: .krw(Constants.openingTotal * (1 + $0.cumulativeRate))
        )
    }

    static let comparison = BenchmarkComparison(
        portfolio: samples.map {
            BenchmarkPoint(date: date(offsetBy: $0.dayOffset), rate: $0.cumulativeRate)
        },
        benchmarks: []
    )

    /// `dayOffset` 0 이 7월 1일, -1 이 그 전날이다. `cumulativeRate` 는 6월 30일을 0 으로 둔
    /// 누적 등락률 — 일간 수익률은 `DailyReturn.series` 가 이웃한 두 값의 차로 되돌린다.
    private static let samples: [(dayOffset: Int, cumulativeRate: Decimal)] = [
        (-1, 0), (0, 0.004), (1, 0.010), (2, 0.008), (3, 0.022),
        (4, 0.021), (5, 0.030), (6, 0.030), (7, 0.012), (8, 0.004),
        (9, 0.018), (10, 0.040),
        (18, 0.036), (19, 0.050), (20, 0.049), (21, 0.062), (22, 0.041),
        (23, 0.055), (24, 0.070), (25, 0.068), (26, 0.082), (27, 0.079),
        (28, 0.094), (29, 0.090), (30, 0.104),
    ]

    // MARK: - Function

    private static func date(offsetBy dayOffset: Int) -> Date {
        monthStart.addingTimeInterval(Constants.secondsPerDay * Double(dayOffset))
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
            exchangeRateService: StubExchangeRateService(),
            now: { PerformanceSampleData.now }
        )
        viewModel.selectBenchmark(.sp500)
        return viewModel
    }

    /// 지수는 골랐지만 비교를 꺼 둔 상태. 벤치마크 시트의 "차트에 겹치기" 스위치가 활성인
    /// 채로 꺼져 있는지(선택 O, disabled 아님) 본다.
    @MainActor
    static var previewWithOverlayOff: PerformanceViewModel {
        let viewModel = PerformanceViewModel.preview
        viewModel.toggleBenchmarkOverlay()
        return viewModel
    }

    /// 히어로(큰 수익률)가 스크롤로 밀려난 뒤 상태. 액세서리 왼쪽이 기간·단위 대신 내
    /// 수익률을 말하는지 본다. computed property 안에서 즉석으로 만들면 부모가 다시 그려질
    /// 때마다 상태가 초기화되므로, 다른 프리뷰들처럼 이름 붙은 static 프로퍼티로 둔다.
    @MainActor
    static var previewWithHeroHidden: PerformanceViewModel {
        let viewModel = PerformanceViewModel.preview
        viewModel.isHeroVisible = false
        return viewModel
    }

    /// 아직 아무 지수도 고르지 않은 상태. 벤치마크 시트의 "차트에 겹치기" 스위치가
    /// `.disabled(true)` 로 내려가는지 본다.
    @MainActor
    static var previewWithoutBenchmark: PerformanceViewModel {
        let viewModel = PerformanceViewModel.preview
        viewModel.selectBenchmark(nil)
        return viewModel
    }

    /// 캘린더 카드 전용. 차트에는 같은 표본이 한 달치만 들어가 어울리지 않으므로 이 인스턴스는
    /// `MonthlyReturnCard` 프리뷰에서만 쓴다.
    @MainActor
    static var previewWithCalendar: PerformanceViewModel {
        PerformanceViewModel(
            calculateYTDReturnUseCase: StubCalculateYTDReturnUseCase { _ in
                PerformanceSampleData.ytdReturn
            },
            fetchNetWorthTrendUseCase: StubFetchNetWorthTrendUseCase { _, _, _ in
                PerformanceCalendarSampleData.points
            },
            compareBenchmarkUseCase: StubCompareBenchmarkUseCase { _, _, _ in
                PerformanceCalendarSampleData.comparison
            },
            exchangeRateService: StubExchangeRateService(),
            now: { PerformanceSampleData.now }
        )
    }

    /// 캘린더 조회만 실패한 상태. 카드 안 실패 문구와 "다시 시도" 가 어떻게 보이는지 본다.
    @MainActor
    static var previewWithCalendarFailure: PerformanceViewModel {
        PerformanceViewModel(
            calculateYTDReturnUseCase: StubCalculateYTDReturnUseCase { _ in
                PerformanceSampleData.ytdReturn
            },
            fetchNetWorthTrendUseCase: StubFetchNetWorthTrendUseCase { _, _, _ in
                throw AppError.network("시세 서버 응답 없음")
            },
            compareBenchmarkUseCase: StubCompareBenchmarkUseCase { _, _, _ in
                PerformanceCalendarSampleData.comparison
            },
            exchangeRateService: StubExchangeRateService(),
            now: { PerformanceSampleData.now }
        )
    }

    /// 기록이 하나도 없는 첫 실행 상태. 요약도 추이도 계산할 근거가 없다.
    @MainActor
    static var previewWithoutRecords: PerformanceViewModel {
        PerformanceViewModel(
            calculateYTDReturnUseCase: StubCalculateYTDReturnUseCase { _ in nil },
            fetchNetWorthTrendUseCase: StubFetchNetWorthTrendUseCase { _, _, _ in [] },
            compareBenchmarkUseCase: StubCompareBenchmarkUseCase { _, _, _ in
                BenchmarkComparison(portfolio: [], benchmarks: [])
            },
            exchangeRateService: StubExchangeRateService(),
            now: { PerformanceSampleData.now }
        )
    }
}

fileprivate enum Constants {
    /// 26일. 8개 점이 한 해를 고르게 덮는 간격이다.
    static let interval: TimeInterval = 60 * 60 * 24 * 26
    static let secondsPerDay: TimeInterval = 60 * 60 * 24
    static let openingTotal: Decimal = 120_000_000
}
#endif
