//
//  PerformanceViewModelTests.swift
//  PerformanceFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDesignSystem
import HannunDomain
import Testing

@testable import PerformanceFeature

@Suite("PerformanceViewModel")
@MainActor
struct PerformanceViewModelTests {

    // MARK: - 로딩

    @Test("첫 로딩이 요약과 추이를 채운다")
    func firstLoadFillsBothStates() async {
        let viewModel = makeViewModel()

        await viewModel.loadIfNeeded()

        let sampledCount = PerformanceSampleData.trendPoints.count
        #expect(
            viewModel.summaryState.value
                == .calculated(rate: PerformanceSampleData.ytdReturn.rate, gain: .krw(9_400_000))
        )
        #expect(viewModel.trendState.value?.portfolio.count == sampledCount)
        #expect(viewModel.isStale == false)
    }

    @Test("계산할 기록이 없으면 실패가 아니라 빈 요약으로 남는다")
    func missingRecordsBecomeEmptySummary() async {
        let viewModel = makeViewModel(ytd: { _ in nil })

        await viewModel.loadIfNeeded()

        #expect(viewModel.summaryState.value == .insufficientData)
        #expect(viewModel.summaryState.error == nil)
        #expect(viewModel.headline == nil)
        #expect(viewModel.isStale == false)
    }

    @Test("이미 불러왔으면 다시 조회하지 않는다")
    func repeatedLoadKeepsFirstResult() async {
        let counter = CallCounter()
        let viewModel = makeViewModel(
            ytd: { _ in
                await counter.increment()
                return PerformanceSampleData.ytdReturn
            }
        )

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(await counter.count == 1)
    }

    @Test("첫 조회 실패는 화면 상태로 알린다")
    func firstFailureSurfacesAsState() async {
        let viewModel = makeViewModel(ytd: { _ in throw AppError.persistence("저장소 오류") })

        await viewModel.loadIfNeeded()

        #expect(viewModel.summaryState == .failed(.persistence("저장소 오류")))
        #expect(viewModel.isStale == false)
    }

    @Test("AppError 가 아닌 에러도 화면 상태로 바뀐다")
    func unknownFailureBecomesAppError() async {
        let viewModel = makeViewModel(ytd: { _ in throw SampleFailure() })

        await viewModel.loadIfNeeded()

        #expect(viewModel.summaryState.error != nil)
        #expect(viewModel.summaryState.value == nil)
    }

    @Test("갱신 실패는 마지막 값을 남기고 배지로만 알린다")
    func refreshFailureKeepsCachedValue() async {
        let counter = CallCounter()
        let viewModel = makeViewModel(
            ytd: { _ in
                await counter.increment()
                guard await counter.count == 1 else { throw AppError.network("시세 서버 응답 없음") }
                return PerformanceSampleData.ytdReturn
            }
        )

        await viewModel.loadIfNeeded()
        await viewModel.refresh()

        #expect(
            viewModel.summaryState.value
                == .calculated(rate: PerformanceSampleData.ytdReturn.rate, gain: .krw(9_400_000))
        )
        #expect(viewModel.isStale)
    }

    // MARK: - 기간·단위

    @Test("기간을 바꾸면 그 구간으로 다시 조회한다")
    func selectingPeriodRequestsNewRange() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, _, granularity in
            await recorder.record(TrendRequest(start: start, granularity: granularity))
            return PerformanceSampleData.trendPoints
        })

        await viewModel.loadIfNeeded()
        await viewModel.selectPeriod(.oneMonth)

        let expected = PerformanceViewModel.dateRange(
            for: .oneMonth,
            now: PerformanceSampleData.now,
            calendar: Self.calendar
        )
        #expect(await recorder.requests.count == 2)
        #expect(await recorder.requests.last?.start == expected.start)
        #expect(viewModel.period == .oneMonth)
    }

    @Test("같은 기간을 다시 고르면 조회하지 않는다")
    func reselectingPeriodSkipsRequest() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, _, granularity in
            await recorder.record(TrendRequest(start: start, granularity: granularity))
            return PerformanceSampleData.trendPoints
        })

        await viewModel.loadIfNeeded()
        await viewModel.selectPeriod(.yearToDate)

        #expect(await recorder.requests.count == 1)
    }

    @Test("단위를 바꾸면 그 단위로 다시 조회한다")
    func selectingGranularityRequestsNewSampling() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, _, granularity in
            await recorder.record(TrendRequest(start: start, granularity: granularity))
            return PerformanceSampleData.trendPoints
        })

        await viewModel.loadIfNeeded()
        await viewModel.selectGranularity(.monthly)

        #expect(await recorder.requests.last?.granularity == .monthly)
        #expect(viewModel.granularity == .monthly)
    }

    @Test("단위가 고른 시점만 차트에 남는다")
    func trendKeepsSampledDatesOnly() async {
        let sampled = [PerformanceSampleData.trendPoints[0], PerformanceSampleData.trendPoints[4]]
        let viewModel = makeViewModel(trend: { _, _, _ in sampled })

        await viewModel.loadIfNeeded()

        #expect(viewModel.trendState.value?.portfolio.map(\.date) == sampled.map(\.date))
    }

    @Test("기간 전환은 스크럽 상태를 해제한다")
    func selectingPeriodClearsScrub() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()
        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        await viewModel.selectPeriod(.threeMonths)

        #expect(viewModel.scrubbedDate == nil)
    }

    @Test(
        "기간별 조회 구간",
        arguments: zip(
            [ChartPeriod.oneMonth, .threeMonths, .sixMonths, .oneYear],
            [1, 3, 6, 12]
        )
    )
    func dateRangeSpansExpectedMonths(period: ChartPeriod, months: Int) {
        let range = PerformanceViewModel.dateRange(
            for: period,
            now: PerformanceSampleData.now,
            calendar: Self.calendar
        )

        let span = Self.calendar.dateComponents([.month], from: range.start, to: range.end)
        #expect(span.month == months)
        #expect(range.end == PerformanceSampleData.now)
    }

    @Test("YTD 는 올해 첫날부터다")
    func yearToDateStartsAtYearOpening() {
        let range = PerformanceViewModel.dateRange(
            for: .yearToDate,
            now: PerformanceSampleData.now,
            calendar: Self.calendar
        )

        #expect(range.start == PerformanceSampleData.yearStart)
    }

    @Test("ALL 은 하한을 두지 않는다")
    func allHasNoLowerBound() {
        let range = PerformanceViewModel.dateRange(
            for: .all,
            now: PerformanceSampleData.now,
            calendar: Self.calendar
        )

        #expect(range.start == .distantPast)
    }

    // MARK: - 벤치마크

    @Test("선택한 지수만 차트에 겹친다")
    func selectedBenchmarkIsOverlaid() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()

        viewModel.toggleBenchmark(.sp500)

        #expect(viewModel.overlaidBenchmark?.index == .sp500)
    }

    @Test("같은 칩을 다시 누르면 선택이 풀린다")
    func togglingSameBenchmarkClearsSelection() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()

        viewModel.toggleBenchmark(.sp500)
        viewModel.toggleBenchmark(.sp500)

        #expect(viewModel.selectedBenchmark == nil)
        #expect(viewModel.overlaidBenchmark == nil)
    }

    @Test("조회에 실패한 지수는 비활성으로 표시된다")
    func failedBenchmarkBecomesUnavailable() async {
        let comparison = BenchmarkComparison(
            portfolio: PerformanceSampleData.comparison.portfolio,
            benchmarks: PerformanceSampleData.comparison.benchmarks.filter { $0.index == .sp500 }
        )
        let viewModel = makeViewModel(comparison: { _, _, _ in comparison })

        await viewModel.loadIfNeeded()

        #expect(viewModel.isBenchmarkAvailable(.sp500))
        #expect(viewModel.isBenchmarkAvailable(.nasdaq) == false)
        #expect(viewModel.isBenchmarkAvailable(.bitcoin) == false)
    }

    @Test("비활성 지수를 골라도 라인을 그리지 않는다")
    func unavailableBenchmarkDrawsNothing() async {
        let comparison = BenchmarkComparison(
            portfolio: PerformanceSampleData.comparison.portfolio,
            benchmarks: []
        )
        let viewModel = makeViewModel(comparison: { _, _, _ in comparison })
        await viewModel.loadIfNeeded()

        viewModel.selectBenchmark(.nasdaq)

        #expect(viewModel.overlaidBenchmark == nil)
    }

    @Test("아직 받아오기 전에는 모든 지수가 활성이다")
    func benchmarksStayEnabledBeforeLoading() {
        let viewModel = makeViewModel()

        #expect(BenchmarkIndex.allCases.allSatisfy { viewModel.isBenchmarkAvailable($0) })
    }

    // MARK: - 스크럽

    @Test("스크럽하면 그 시점 값이 헤드라인을 대신한다")
    func scrubbingReplacesHeadline() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()

        let scrubbedDate = PerformanceSampleData.date(at: 3)
        viewModel.scrubbedDate = scrubbedDate

        #expect(viewModel.headline?.isScrubbing == true)
        #expect(viewModel.headline?.scrubbedDate == scrubbedDate)
        #expect(viewModel.headline?.rate == 0.031)
        #expect(viewModel.headline?.amount == .krw(123_720_000))
    }

    @Test("손을 떼면 연초 대비로 돌아온다")
    func releasingScrubRestoresYearToDate() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()
        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        viewModel.scrubbedDate = nil

        #expect(viewModel.headline?.isScrubbing == false)
        #expect(viewModel.headline?.rate == PerformanceSampleData.ytdReturn.rate)
        #expect(viewModel.headline?.amount == .krw(9_400_000))
    }

    @Test("차트에 없는 시점은 헤드라인을 바꾸지 않는다")
    func unknownScrubDateIsIgnored() async {
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()

        viewModel.scrubbedDate = .distantFuture

        #expect(viewModel.headline?.isScrubbing == false)
        #expect(viewModel.headline?.rate == PerformanceSampleData.ytdReturn.rate)
    }

    // MARK: - Function

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func makeViewModel(
        ytd: @escaping @Sendable (Date) async throws -> YTDReturn? = { _ in
            PerformanceSampleData.ytdReturn
        },
        trend: @escaping @Sendable (Date, Date, TrendGranularity) async throws
            -> [NetWorthTrendPoint] = { _, _, _ in PerformanceSampleData.trendPoints },
        comparison: @escaping @Sendable (Date, Date, [BenchmarkIndex]) async throws
            -> BenchmarkComparison = { _, _, _ in PerformanceSampleData.comparison }
    ) -> PerformanceViewModel {
        PerformanceViewModel(
            calculateYTDReturnUseCase: StubCalculateYTDReturnUseCase(result: ytd),
            fetchNetWorthTrendUseCase: StubFetchNetWorthTrendUseCase(result: trend),
            compareBenchmarkUseCase: StubCompareBenchmarkUseCase(result: comparison),
            exchangeRateService: StubExchangeRateService(),
            calendar: Self.calendar,
            now: { PerformanceSampleData.now }
        )
    }
}

/// 조회 호출 횟수를 세는 도구. 스텁 클로저가 동시성 경계를 넘으므로 actor 로 감싼다.
private actor CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

private struct TrendRequest: Equatable, Sendable {
    let start: Date
    let granularity: TrendGranularity
}

private actor TrendRequestRecorder {
    private(set) var requests: [TrendRequest] = []

    func record(_ request: TrendRequest) {
        requests.append(request)
    }
}

/// `AppError` 로 매핑되지 않는 에러가 들어오는 경로를 확인하기 위한 표본.
private struct SampleFailure: Error {}
