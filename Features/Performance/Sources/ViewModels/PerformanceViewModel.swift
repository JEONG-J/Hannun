//
//  PerformanceViewModel.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDesignSystem
import HannunDomain
import Observation

/// 투자 성과 탭의 상태 소유자 (PM-2 ~ PM-4).
@MainActor
@Observable
final class PerformanceViewModel {

    // MARK: - Property

    private(set) var summaryState: Loadable<PerformanceSummary> = .idle
    private(set) var trendState: Loadable<PerformanceTrend> = .idle

    private(set) var period: ChartPeriod = Constants.initialPeriod
    private(set) var granularity: TrendGranularity = Constants.initialGranularity
    private(set) var selectedBenchmark: BenchmarkIndex?

    /// 스크럽 중인 시점. 차트가 직접 갱신하므로 바인딩할 수 있어야 한다.
    var scrubbedDate: Date?

    private(set) var isSummaryStale = false
    private(set) var isTrendStale = false

    private let calculateYTDReturnUseCase: any CalculateYTDReturnUseCaseProtocol
    private let fetchNetWorthTrendUseCase: any FetchNetWorthTrendUseCaseProtocol
    private let compareBenchmarkUseCase: any CompareBenchmarkUseCaseProtocol
    private let calendar: Calendar
    private let now: () -> Date

    /// 마지막 값을 지운 채 실패로 떨어졌는지 여부. 갱신 실패는 배지로만 알린다 (UI 스펙 §4).
    var isStale: Bool { isSummaryStale || isTrendStale }

    /// 상단 큰 숫자. 스크럽 중이면 그 시점 값이 연초 대비 값을 대신한다.
    var headline: PerformanceHeadline? {
        if let scrubbedHeadline { return scrubbedHeadline }
        guard let summary = summaryState.value else { return nil }

        return PerformanceHeadline(scrubbedDate: nil, rate: summary.rate, amount: summary.gain)
    }

    /// 차트에 겹칠 벤치마크. 선택이 없거나 조회에 실패한 지수면 아무것도 그리지 않는다.
    var overlaidBenchmark: BenchmarkSeries? {
        guard let selectedBenchmark else { return nil }
        return trendState.value?.benchmarks.first { $0.index == selectedBenchmark }
    }

    private var scrubbedHeadline: PerformanceHeadline? {
        guard
            let scrubbedDate,
            let trend = trendState.value,
            let point = trend.portfolio.first(where: { $0.date == scrubbedDate })
        else { return nil }

        return PerformanceHeadline(
            scrubbedDate: scrubbedDate,
            rate: point.rate,
            amount: trend.totals[scrubbedDate]
        )
    }

    // MARK: - Function

    init(
        calculateYTDReturnUseCase: any CalculateYTDReturnUseCaseProtocol,
        fetchNetWorthTrendUseCase: any FetchNetWorthTrendUseCaseProtocol,
        compareBenchmarkUseCase: any CompareBenchmarkUseCaseProtocol,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.calculateYTDReturnUseCase = calculateYTDReturnUseCase
        self.fetchNetWorthTrendUseCase = fetchNetWorthTrendUseCase
        self.compareBenchmarkUseCase = compareBenchmarkUseCase
        self.calendar = calendar
        self.now = now
    }

    convenience init(container: DIContainer) {
        self.init(
            calculateYTDReturnUseCase: container.resolve(
                (any CalculateYTDReturnUseCaseProtocol).self
            ),
            fetchNetWorthTrendUseCase: container.resolve(
                (any FetchNetWorthTrendUseCaseProtocol).self
            ),
            compareBenchmarkUseCase: container.resolve(
                (any CompareBenchmarkUseCaseProtocol).self
            )
        )
    }

    /// 탭에 처음 들어왔을 때만 받아온다. 탭을 오갈 때마다 다시 부르지 않는다.
    func loadIfNeeded() async {
        guard case .idle = summaryState else { return }
        await refresh()
    }

    func refresh() async {
        await loadSummary()
        await loadTrend()
    }

    func selectPeriod(_ period: ChartPeriod) async {
        guard period != self.period else { return }

        self.period = period
        scrubbedDate = nil
        await loadTrend()
    }

    func selectGranularity(_ granularity: TrendGranularity) async {
        guard granularity != self.granularity else { return }

        self.granularity = granularity
        scrubbedDate = nil
        await loadTrend()
    }

    /// 같은 칩을 다시 누르면 선택이 풀린다 — 기본 표시 벤치마크는 0~1개다 (UI 스펙 §4.3).
    func toggleBenchmark(_ index: BenchmarkIndex) {
        selectBenchmark(selectedBenchmark == index ? nil : index)
    }

    func selectBenchmark(_ index: BenchmarkIndex?) {
        selectedBenchmark = index
    }

    /// 아직 받아오기 전에는 전부 활성으로 둔다 — 없다고 단정할 근거가 없다.
    func isBenchmarkAvailable(_ index: BenchmarkIndex) -> Bool {
        guard let trend = trendState.value else { return true }
        return !trend.unavailableIndices.contains(index)
    }

    /// 기간 세그먼트가 고른 구간. `.all` 은 첫 기록 시점을 알 수 없어 하한을 두지 않는다.
    static func dateRange(
        for period: ChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start: Date? = switch period {
        case .oneMonth:
            calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            calendar.date(byAdding: .month, value: -6, to: now)
        case .yearToDate:
            calendar.date(from: calendar.dateComponents([.year], from: now))
        case .oneYear:
            calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            Date.distantPast
        }

        return (start ?? .distantPast, now)
    }

    private func loadSummary() async {
        if summaryState.value == nil { summaryState = .loading }

        do {
            let ytdReturn = try await calculateYTDReturnUseCase.execute(
                asOf: now(),
                baseCurrency: Constants.baseCurrency,
                exchangeRate: Constants.assumedExchangeRate
            )
            summaryState = .loaded(PerformanceSummary(ytdReturn))
            isSummaryStale = false
        } catch {
            summaryState = retaining(summaryState, after: error, markingStale: &isSummaryStale)
        }
    }

    private func loadTrend() async {
        if trendState.value == nil { trendState = .loading }

        let range = Self.dateRange(for: period, now: now(), calendar: calendar)
        let indices = BenchmarkIndex.allCases

        do {
            let sampledPoints = try await fetchNetWorthTrendUseCase.execute(
                from: range.start,
                to: range.end,
                granularity: granularity,
                baseCurrency: Constants.baseCurrency
            )
            let comparison = try await compareBenchmarkUseCase.execute(
                from: range.start,
                to: range.end,
                indices: indices,
                baseCurrency: Constants.baseCurrency,
                exchangeRate: Constants.assumedExchangeRate
            )

            trendState = .loaded(
                PerformanceTrend(
                    requesting: indices,
                    sampledPoints: sampledPoints,
                    comparison: comparison
                )
            )
            isTrendStale = false
        } catch {
            trendState = retaining(trendState, after: error, markingStale: &isTrendStale)
        }
    }

    /// 첫 로딩 실패는 화면 상태로 알리고, 갱신 실패는 마지막 값을 남긴 채 배지로만 알린다.
    private func retaining<Value>(
        _ state: Loadable<Value>,
        after error: any Error,
        markingStale isStale: inout Bool
    ) -> Loadable<Value> {
        guard let cached = state.value else {
            return .failed(error as? AppError ?? .unknown(String(describing: error)))
        }

        isStale = true
        return .loaded(cached)
    }
}

fileprivate enum Constants {
    static let baseCurrency: Currency = .krw
    static let initialPeriod: ChartPeriod = .yearToDate
    static let initialGranularity: TrendGranularity = .daily

    /// 환율 조회 UseCase 가 아직 없다. 성과 탭은 원화 기준이라 환산이 개입하는 지점은
    /// 외화 입출금뿐이므로 고정값으로 두고, 조회 경로가 생기면 이 상수만 걷어낸다.
    static let assumedExchangeRate = ExchangeRate(krwPerUSD: 1_300)
}
