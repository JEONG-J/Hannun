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

        await viewModel.refresh()

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

        await viewModel.refresh()

        #expect(viewModel.summaryState.value == .insufficientData)
        #expect(viewModel.summaryState.error == nil)
        #expect(viewModel.headline == nil)
        #expect(viewModel.isStale == false)
    }

    @Test("성과를 읽기 전에 오늘자 스냅샷을 먼저 남긴다")
    func loadRecordsTodaySnapshotBeforeReading() async {
        let log = SnapshotCallLog()
        let viewModel = makeViewModel(
            record: { await log.recordSnapshot(asOf: $0) },
            ytd: { _ in
                await log.readSummary()
                return PerformanceSampleData.ytdReturn
            }
        )

        await viewModel.refresh()

        #expect(await log.recordedDates == [PerformanceSampleData.now])
        #expect(await log.events.first == .snapshot)
    }

    @Test("탭에 다시 들어오면 다시 조회한다")
    func repeatedLoadRereads() async {
        let counter = CallCounter()
        let viewModel = makeViewModel(
            ytd: { _ in
                await counter.increment()
                return PerformanceSampleData.ytdReturn
            }
        )

        await viewModel.refresh()
        await viewModel.refresh()

        #expect(await counter.count == 2)
    }

    @Test("첫 조회 실패는 화면 상태로 알린다")
    func firstFailureSurfacesAsState() async {
        let viewModel = makeViewModel(ytd: { _ in throw AppError.persistence("저장소 오류") })

        await viewModel.refresh()

        #expect(viewModel.summaryState == .failed(.persistence("저장소 오류")))
        #expect(viewModel.isStale == false)
    }

    @Test("AppError 가 아닌 에러도 화면 상태로 바뀐다")
    func unknownFailureBecomesAppError() async {
        let viewModel = makeViewModel(ytd: { _ in throw SampleFailure() })

        await viewModel.refresh()

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

        await viewModel.refresh()
        await viewModel.refresh()

        #expect(
            viewModel.summaryState.value
                == .calculated(rate: PerformanceSampleData.ytdReturn.rate, gain: .krw(9_400_000))
        )
        #expect(viewModel.isStale)
    }

    // MARK: - 기록 없음

    /// 요약이 오기 전에는 카드를 그릴지 **정할 수 없다**. 그 구간을 "기록이 있다"로 단정하면
    /// 탭에 들어서는 첫 프레임에 스피너 두 장이 떴다가, 로컬 조회라 곧바로 도착하는 요약이
    /// `.insufficientData` 인 순간 그대로 사라진다 — 눈에 남는 건 뭔가 반짝했다는 인상뿐이다.
    @Test("요약을 기다리는 동안에는 카드를 그리지 않는다")
    func cardsStayHiddenUntilSummaryArrives() async {
        let hasEnteredSummaryRequest = RequestGate()
        let summaryGate = RequestGate()
        let viewModel = makeViewModel(
            ytd: { _ in
                await hasEnteredSummaryRequest.signal()
                await summaryGate.wait()
                return nil
            }
        )

        // 탭에 들어서기 전. 아직 아무것도 조회하지 않았다.
        #expect(viewModel.hasNoRecords != false)

        async let refresh: Void = viewModel.refresh()
        await hasEnteredSummaryRequest.wait()

        #expect(viewModel.summaryState.isLoading)
        #expect(viewModel.hasNoRecords != false)

        await summaryGate.signal()
        await refresh
    }

    /// 요약은 로컬이라 즉시 끝나고 추이는 지수 네트워크 왕복을 태워 늦게 온다. 그 사이를
    /// 감추지 않으면 빈 상태 아래에서 차트·캘린더 카드가 스피너만 돌리다 사라진다.
    @Test("기록이 없으면 추이를 기다리는 동안에도 카드를 감춘다")
    func noRecordsHidesCardsWhileTrendLoads() async {
        let hasEnteredTrendRequest = RequestGate()
        let trendGate = RequestGate()
        let viewModel = makeViewModel(
            ytd: { _ in nil },
            trend: { _, _, _ in
                await hasEnteredTrendRequest.signal()
                await trendGate.wait()
                return []
            }
        )

        async let refresh: Void = viewModel.refresh()
        await hasEnteredTrendRequest.wait()

        #expect(viewModel.summaryState.value == .insufficientData)
        #expect(viewModel.trendState.isLoading)
        #expect(viewModel.hasNoRecords == true)

        await trendGate.signal()
        await refresh

        #expect(viewModel.hasNoRecords == true)
    }

    /// 연초 기록만 없고 그 이전 기록은 있을 수 있다 — YTD 만 못 낼 뿐 차트는 멀쩡하다.
    @Test("추이에 그릴 점이 있으면 요약이 비어도 카드를 남긴다")
    func trendWithPointsKeepsCardsVisible() async {
        let viewModel = makeViewModel(ytd: { _ in nil })

        await viewModel.refresh()

        #expect(viewModel.summaryState.value == .insufficientData)
        #expect(viewModel.hasNoRecords == false)
    }

    /// 감추면 차트 카드 안의 실패 문구와 다시 시도 버튼까지 함께 사라진다.
    @Test("추이 조회가 실패하면 카드를 감추지 않는다")
    func trendFailureKeepsCardsVisible() async {
        let viewModel = makeViewModel(
            ytd: { _ in nil },
            trend: { _, _, _ in throw AppError.network("시세 서버 응답 없음") }
        )

        await viewModel.refresh()

        #expect(viewModel.trendState.error != nil)
        #expect(viewModel.hasNoRecords == false)
    }

    // MARK: - 기간·단위

    @Test("기간을 바꾸면 그 구간으로 다시 조회한다")
    func selectingPeriodRequestsNewRange() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        await viewModel.selectPeriod(.oneMonth)

        let expected = PerformanceViewModel.dateRange(
            for: .oneMonth,
            now: PerformanceSampleData.now,
            calendar: Self.calendar
        )
        #expect(await recorder.chartRequests.count == 2)
        #expect(await recorder.chartRequests.last?.start == expected.start)
        #expect(viewModel.period == .oneMonth)
    }

    @Test("같은 기간을 다시 고르면 조회하지 않는다")
    func reselectingPeriodSkipsRequest() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        await viewModel.selectPeriod(.yearToDate)

        #expect(await recorder.chartRequests.count == 1)
    }

    @Test("단위를 바꾸면 그 단위로 다시 조회한다")
    func selectingGranularityRequestsNewSampling() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        await viewModel.selectGranularity(.monthly)

        #expect(await recorder.requests.last?.granularity == .monthly)
        #expect(viewModel.granularity == .monthly)
    }

    @Test("단위를 왕복해 골라도 매번 재조회한다")
    func alternatingGranularityRefetchesEachTime() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        await viewModel.selectGranularity(.monthly)
        await viewModel.selectGranularity(.daily)

        #expect(await recorder.chartRequests.map(\.granularity) == [.daily, .monthly, .daily])
        #expect(viewModel.granularity == .daily)
    }

    @Test("단위를 바꾸면 스크럽 상태가 풀린다")
    func selectingGranularityClearsScrub() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        await viewModel.selectGranularity(.monthly)

        #expect(viewModel.scrubbedDate == nil)
    }

    @Test("단위를 빠르게 두 번 눌러도 나중에 시작한 요청 결과만 반영된다")
    func rapidGranularityChangesKeepLatestRequestWinning() async {
        // 첫 선택(.monthly)은 문을 걸어 두고, 그 사이 두 번째 선택(.daily)이 먼저 끝나게 만든다.
        // 이 순서에서 첫 선택이 나중에 풀려도 결과를 덮어써서는 안 된다 — 화면에 남는 값은
        // 항상 사용자의 마지막 조작(.daily)과 맞아야 한다.
        let gate = RequestGate()
        let viewModel = makeViewModel(trend: { _, _, granularity in
            if granularity == .monthly {
                await gate.wait()
                return PerformanceSampleData.trendPoints
            }
            return Array(PerformanceSampleData.trendPoints.prefix(2))
        })

        await viewModel.refresh()

        async let first: Void = viewModel.selectGranularity(.monthly)
        async let second: Void = viewModel.selectGranularity(.daily)
        await second

        #expect(viewModel.granularity == .daily)
        #expect(viewModel.trendState.value?.portfolio.count == 2)

        await gate.signal()
        await first

        #expect(viewModel.granularity == .daily)
        #expect(viewModel.trendState.value?.portfolio.count == 2)
    }

    @Test("기간을 고르면 그 기간이 차트에 반영된다")
    func selectingPeriodUpdatesChart() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        await viewModel.selectPeriod(.oneMonth)

        #expect(viewModel.period == .oneMonth)
    }

    @Test("단위가 고른 시점만 차트에 남는다")
    func trendKeepsSampledDatesOnly() async {
        let sampled = [PerformanceSampleData.trendPoints[0], PerformanceSampleData.trendPoints[4]]
        let viewModel = makeViewModel(trend: { _, _, _ in sampled })

        await viewModel.refresh()

        #expect(viewModel.trendState.value?.portfolio.map(\.date) == sampled.map(\.date))
    }

    @Test("기간 전환은 스크럽 상태를 해제한다")
    func selectingPeriodClearsScrub() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
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

    /// 직접 고른 구간만 종료 시각을 스스로 갖는다 — 프리셋처럼 `now` 로 끊기면 지난 구간을
    /// 떼어 볼 수 없다.
    @Test("직접 고른 구간은 두 끝점을 그대로 쓴다")
    func customPeriodKeepsBothEndpoints() {
        let start = Self.date(year: 2025, month: 3, day: 1)
        let end = Self.date(year: 2025, month: 9, day: 30, hour: 23, minute: 59, second: 59)

        let range = PerformanceViewModel.dateRange(
            for: .custom(start: start, end: end),
            now: PerformanceSampleData.now,
            calendar: Self.calendar
        )

        #expect(range.start == start)
        #expect(range.end == end)
    }

    /// 알약 하나에 들어가야 하는 라벨이라 년.월 로만 적는다. 두 끝점을 달 한가운데로 잡아
    /// 실행 시간대가 달라도 같은 달을 가리키게 한다 — `title` 은 표시용이라 사용자 달력을 쓴다.
    @Test("직접 고른 구간의 라벨은 년.월 두 개다")
    func customPeriodTitleIsShort() {
        let period = ChartPeriod.custom(
            start: Self.date(year: 2026, month: 1, day: 15, hour: 12),
            end: Self.date(year: 2026, month: 8, day: 20, hour: 12)
        )

        #expect(period.title == "2026.1 – 2026.8")
    }

    // MARK: - 표시 단위

    /// 시점별 총자산은 이미 `trend.totals` 에 들어 있다. 축만 바꾸는 조작이 조회를 태우면
    /// 왕복할 때마다 네트워크가 두 번 뛴다.
    @Test("표시 단위를 바꿔도 다시 조회하지 않는다")
    func togglingValueUnitSkipsRefetch() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        viewModel.toggleValueUnit()
        viewModel.toggleValueUnit()

        #expect(await recorder.chartRequests.count == 1)
        #expect(viewModel.valueUnit == .percent)
    }

    @Test("표시 단위는 누를 때마다 반대로 간다")
    func togglingValueUnitFlipsBothWays() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.toggleValueUnit()

        #expect(viewModel.valueUnit == .amount)

        viewModel.toggleValueUnit()

        #expect(viewModel.valueUnit == .percent)
    }

    /// 지수는 등락률이라 원화 축에 얹으면 두 선의 기울기가 서로 무관해진다. 고른 지수 자체는
    /// 남아 있어야 % 로 되돌렸을 때 그대로 다시 겹친다.
    @Test("금액 축에서는 비교가 켜져 있어도 겹치지 않는다")
    func amountUnitDropsBenchmarkOverlay() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.selectBenchmark(.sp500)

        viewModel.toggleValueUnit()

        #expect(viewModel.overlaidBenchmark == nil)
        #expect(viewModel.benchmarkExcessReturn == nil)
        #expect(viewModel.selectedBenchmark == .sp500)
        #expect(viewModel.isBenchmarkOverlayEnabled)

        viewModel.toggleValueUnit()

        #expect(viewModel.overlaidBenchmark?.index == .sp500)
        #expect(viewModel.benchmarkExcessReturn != nil)
    }

    @Test("총 평가금액은 추이 마지막 시점의 총자산이다")
    func latestTotalComesFromTheLastTrendPoint() async {
        let viewModel = makeViewModel()

        await viewModel.refresh()

        #expect(viewModel.latestTotal == PerformanceSampleData.trendPoints.last?.total)
    }

    @Test("추이에 기록이 없으면 총 평가금액도 없다")
    func latestTotalIsMissingWithoutTrend() async {
        let viewModel = makeViewModel(trend: { _, _, _ in [] })

        await viewModel.refresh()

        #expect(viewModel.latestTotal == nil)
    }

    // MARK: - 벤치마크

    @Test("선택한 지수만 차트에 겹친다")
    func selectedBenchmarkIsOverlaid() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.toggleBenchmark(.sp500)

        #expect(viewModel.overlaidBenchmark?.index == .sp500)
    }

    @Test("같은 지수를 다시 고르면 선택이 풀린다")
    func togglingSameBenchmarkClearsSelection() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.toggleBenchmark(.sp500)
        viewModel.toggleBenchmark(.sp500)

        #expect(viewModel.selectedBenchmark == nil)
        #expect(viewModel.overlaidBenchmark == nil)
        #expect(viewModel.isBenchmarkOverlayEnabled == false)
    }

    @Test("비교를 껐다 켜도 고른 지수는 남는다")
    func togglingOverlayKeepsSelection() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.selectBenchmark(.sp500)

        viewModel.toggleBenchmarkOverlay()

        #expect(viewModel.selectedBenchmark == .sp500)
        #expect(viewModel.overlaidBenchmark == nil)

        viewModel.toggleBenchmarkOverlay()

        #expect(viewModel.overlaidBenchmark?.index == .sp500)
    }

    @Test("고른 지수가 없으면 비교를 켤 수 없다")
    func overlayCannotEnableWithoutSelection() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.toggleBenchmarkOverlay()

        #expect(viewModel.isBenchmarkOverlayEnabled == false)
    }

    @Test("초과수익은 마지막 시점의 수익률 차다")
    func excessReturnIsTheLastPointDifference() async throws {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.selectBenchmark(.sp500)

        // 표본 마지막 시점: 내 9.4% - S&P500 5.1% = 4.3%p.
        // 표본 비율이 부동소수 리터럴에서 왔으므로 표시 자릿수(0.1%p) 안에서만 따진다.
        let excess = try #require(viewModel.benchmarkExcessReturn)
        #expect(abs(excess - Constants.expectedExcessReturn) < Constants.excessReturnTolerance)
    }

    @Test("비교가 꺼져 있으면 초과수익도 말하지 않는다")
    func excessReturnNeedsOverlay() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.selectBenchmark(.sp500)

        viewModel.toggleBenchmarkOverlay()

        #expect(viewModel.benchmarkExcessReturn == nil)
    }

    @Test("조회에 실패한 지수는 비활성으로 표시된다")
    func failedBenchmarkBecomesUnavailable() async {
        let comparison = BenchmarkComparison(
            portfolio: PerformanceSampleData.comparison.portfolio,
            benchmarks: PerformanceSampleData.comparison.benchmarks.filter { $0.index == .sp500 }
        )
        let viewModel = makeViewModel(comparison: { _, _, _ in comparison })

        await viewModel.refresh()

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
        await viewModel.refresh()

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
        await viewModel.refresh()

        let scrubbedDate = PerformanceSampleData.date(at: 3)
        viewModel.scrubbedDate = scrubbedDate

        #expect(viewModel.headline?.isFocused == true)
        #expect(viewModel.headline?.focusedDate == scrubbedDate)
        #expect(viewModel.headline?.rate == 0.031)
        #expect(viewModel.headline?.amount == .krw(123_720_000))
    }

    @Test("손을 떼면 연초 대비로 돌아온다")
    func releasingScrubRestoresYearToDate() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        viewModel.scrubbedDate = nil

        #expect(viewModel.headline?.isFocused == false)
        #expect(viewModel.headline?.rate == PerformanceSampleData.ytdReturn.rate)
        #expect(viewModel.headline?.amount == .krw(9_400_000))
    }

    @Test("차트에 없는 시점은 헤드라인을 바꾸지 않는다")
    func unknownScrubDateIsIgnored() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.scrubbedDate = .distantFuture

        #expect(viewModel.headline?.isFocused == false)
        #expect(viewModel.headline?.rate == PerformanceSampleData.ytdReturn.rate)
    }

    @Test("첫 로딩 직후에는 스크럽 가이드 힌트가 보인다")
    func hintIsVisibleAfterFirstLoad() async {
        let viewModel = makeViewModel()

        await viewModel.refresh()

        #expect(viewModel.isScrubHintVisible)
    }

    @Test("스크럽하면 배웠다고 기록하고 힌트를 감춘다")
    func scrubbingMarksAsLearnedAndHidesHint() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        #expect(viewModel.hasScrubbed)
        #expect(viewModel.isScrubHintVisible == false)
    }

    @Test("손을 떼도 한 번 배운 힌트는 되살아나지 않는다")
    func releasingScrubKeepsHintHidden() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        viewModel.scrubbedDate = nil

        #expect(viewModel.isScrubHintVisible == false)
    }

    @Test("스크럽 후 기간을 바꿔도 힌트는 되살아나지 않는다")
    func changingPeriodAfterScrubKeepsHintHidden() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.scrubbedDate = PerformanceSampleData.date(at: 3)

        await viewModel.selectPeriod(.oneMonth)

        #expect(viewModel.isScrubHintVisible == false)
    }

    @Test("로딩 중에는 힌트를 보이지 않는다")
    func hintStaysHiddenWhileLoading() {
        let viewModel = makeViewModel()

        #expect(viewModel.isScrubHintVisible == false)
    }

    @Test("추이 조회에 실패하면 힌트를 보이지 않는다")
    func hintStaysHiddenOnFailure() async {
        let viewModel = makeViewModel(
            trend: { _, _, _ in throw AppError.network("시세 서버 응답 없음") }
        )

        await viewModel.refresh()

        #expect(viewModel.isScrubHintVisible == false)
    }

    @Test("추이 점이 하나뿐이면 힌트를 보이지 않는다")
    func hintStaysHiddenWithSinglePoint() async {
        let viewModel = makeViewModel(trend: { _, _, _ in [PerformanceSampleData.trendPoints[0]] })

        await viewModel.refresh()

        #expect(viewModel.isScrubHintVisible == false)
    }

    // MARK: - 날짜 선택

    @Test("캘린더에서 고른 날이 헤드라인과 차트 커서를 옮긴다")
    func selectingDateMovesHeadlineAndCursor() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        let selected = PerformanceSampleData.date(at: 3)

        viewModel.selectDate(selected)

        #expect(viewModel.selectedDate == selected)
        #expect(viewModel.focusedDate == selected)
        #expect(viewModel.chartCursorDate == selected)
        #expect(viewModel.headline?.isFocused == true)
        #expect(viewModel.headline?.focusedDate == selected)
        #expect(viewModel.headline?.rate == 0.031)
    }

    @Test("고른 날을 다시 누르면 선택이 풀린다")
    func reselectingTheSameDateClearsSelection() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        let selected = PerformanceSampleData.date(at: 3)
        viewModel.selectDate(selected)

        viewModel.selectDate(selected)

        #expect(viewModel.selectedDate == nil)
        #expect(viewModel.chartCursorDate == nil)
        #expect(viewModel.headline?.isFocused == false)
    }

    @Test("스크럽이 고른 날을 덮고, 손을 떼면 다시 그 날로 돌아온다")
    func scrubbingOverridesSelectionAndReleasingRestoresIt() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        let selected = PerformanceSampleData.date(at: 3)
        let scrubbed = PerformanceSampleData.date(at: 5)
        viewModel.selectDate(selected)

        viewModel.scrubbedDate = scrubbed

        #expect(viewModel.focusedDate == scrubbed)
        #expect(viewModel.headline?.focusedDate == scrubbed)

        viewModel.scrubbedDate = nil

        // 손을 뗐다고 연초 대비로 돌아가지는 않는다 — 캘린더 선택이 아직 살아 있다.
        #expect(viewModel.focusedDate == selected)
        #expect(viewModel.headline?.focusedDate == selected)
    }

    @Test("차트가 담지 않은 날을 골라도 헤드라인은 연초 대비 그대로다")
    func selectingDateOutsideTheChartKeepsYearToDate() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        let outside = Self.date(year: 2023, month: 3, day: 14)

        viewModel.selectDate(outside)

        // 선택 자체는 남는다 — 캘린더 셀의 링은 그려야 하기 때문이다.
        #expect(viewModel.selectedDate == outside)
        #expect(viewModel.chartCursorDate == nil)
        #expect(viewModel.headline?.isFocused == false)
        #expect(viewModel.headline?.rate == PerformanceSampleData.ytdReturn.rate)
    }

    @Test("월별 단위에서는 고른 날이 같은 달 점으로 스냅된다")
    func monthlyGranularitySnapsSelectionToItsMonth() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        await viewModel.selectGranularity(.monthly)

        viewModel.selectDate(Self.date(year: 2026, month: 3, day: 31))

        #expect(viewModel.chartCursorDate == PerformanceSampleData.date(at: 3))
        #expect(viewModel.headline?.rate == 0.031)
    }

    @Test("기간·단위를 바꿔도 고른 날은 남는다")
    func changingPeriodOrGranularityKeepsSelection() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        let selected = PerformanceSampleData.date(at: 3)
        viewModel.selectDate(selected)

        await viewModel.selectPeriod(.oneMonth)

        #expect(viewModel.selectedDate == selected)

        await viewModel.selectGranularity(.monthly)

        #expect(viewModel.selectedDate == selected)
    }

    // MARK: - 캘린더

    @Test("캘린더는 그 달 하루 전부터 말일 끝까지 조회한다")
    func calendarQueryStartsOneDayBeforeTheMonth() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return []
        })

        await viewModel.loadCalendar()

        // 7월 1일의 일간 수익률에는 6월 30일 총자산이 필요하다 — 하루를 더 받아온다.
        let request = await recorder.requests.last
        #expect(request?.start == Self.date(year: 2026, month: 6, day: 30))
        #expect(
            request?.end
                == Self.date(year: 2026, month: 7, day: 31, hour: 23, minute: 59, second: 59)
        )
    }

    @Test("차트가 월별을 보고 있어도 캘린더는 일별로 조회한다")
    func calendarStaysDailyWhileChartIsMonthly() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        await viewModel.selectGranularity(.monthly)
        await viewModel.loadCalendar()

        // 월별 샘플링을 그대로 물려받으면 "전월 대비" 수익률이 일별 격자에 칠해진다.
        #expect(viewModel.granularity == .monthly)
        #expect(await recorder.requests.last?.granularity == .daily)
    }

    @Test("캘린더 조회는 기간 세그먼트가 고른 구간을 따라가지 않는다")
    func calendarRangeIgnoresChartPeriod() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return PerformanceSampleData.trendPoints
        })

        await viewModel.refresh()
        await viewModel.selectPeriod(.oneYear)
        await viewModel.loadCalendar()

        #expect(await recorder.requests.last?.start == Self.date(year: 2026, month: 6, day: 30))
    }

    @Test("캘린더 조회는 지수를 하나도 요청하지 않는다")
    func calendarQueryAsksForNoBenchmarkIndices() async {
        let recorder = ComparisonRequestRecorder()
        let viewModel = makeViewModel(comparison: { start, _, indices in
            await recorder.record(ComparisonRequest(start: start, indices: indices))
            return PerformanceSampleData.comparison
        })

        await viewModel.refresh()

        // 차트는 전 지수를, 캘린더는 빈 목록을 요청한다 — 빈 목록이면 지수 저장소를 돌지 않는다.
        #expect(await recorder.requests.first?.indices == BenchmarkIndex.allCases)
        #expect(await recorder.requests.last?.indices == [])
    }

    @Test("그 달 밖의 날은 파생 결과에서 걸러진다")
    func calendarKeepsDisplayedMonthOnly() async {
        // 하루에 기록이 둘이면 더 받아온 하루(6월 30일)에서도 파생값이 생긴다. 8월 1일은
        // 조회 구간 밖이지만 저장소가 넉넉히 돌려줘도 격자에 새지 않아야 한다.
        let samples: [(date: Date, rate: Decimal)] = [
            (Self.date(year: 2026, month: 6, day: 30, hour: 9), 0),
            (Self.date(year: 2026, month: 6, day: 30, hour: 21), 0.004),
            (Self.date(year: 2026, month: 7, day: 1), 0.010),
            (Self.date(year: 2026, month: 7, day: 2), 0.006),
            (Self.date(year: 2026, month: 8, day: 1), 0.020),
        ]
        let viewModel = makeViewModel(
            trend: { _, _, _ in Self.trendPoints(of: samples) },
            comparison: { _, _, _ in Self.comparison(of: samples) }
        )

        await viewModel.loadCalendar()

        #expect(
            viewModel.calendarState.value?.map(\.date) == [
                Self.date(year: 2026, month: 7, day: 1),
                Self.date(year: 2026, month: 7, day: 2),
            ]
        )
    }

    /// 이슈 #22 — 며칠 건너뛴 뒤 첫 실행. 백필된 날은 전일과 총자산이 같아 차분이 0 이라,
    /// 걸러내지 않으면 "시세를 못 받은 날" 이 "변동 없던 날" 과 같은 회색 0% 셀이 된다.
    @Test("앱을 안 켠 날은 캘린더에서 빠지고 다시 켠 날만 남는다")
    func calendarExcludesCarriedForwardDays() async {
        let samples: [(date: Date, rate: Decimal, isCarriedForward: Bool)] = [
            (Self.date(year: 2026, month: 6, day: 30), 0, false),
            (Self.date(year: 2026, month: 7, day: 1), 0.010, false),
            (Self.date(year: 2026, month: 7, day: 2), 0.010, true),
            (Self.date(year: 2026, month: 7, day: 3), 0.010, true),
            (Self.date(year: 2026, month: 7, day: 4), 0.020, false),
        ]
        let viewModel = makeViewModel(
            trend: { _, _, _ in
                samples.map {
                    NetWorthTrendPoint(
                        date: $0.date,
                        total: .krw(Constants.sampleOpeningTotal * (1 + $0.rate)),
                        isCarriedForward: $0.isCarriedForward
                    )
                }
            },
            comparison: { _, _, _ in
                BenchmarkComparison(
                    portfolio: samples.map { BenchmarkPoint(date: $0.date, rate: $0.rate) },
                    benchmarks: []
                )
            }
        )

        await viewModel.loadCalendar()

        #expect(
            viewModel.calendarState.value?.map(\.date) == [
                Self.date(year: 2026, month: 7, day: 1),
                Self.date(year: 2026, month: 7, day: 4),
            ]
        )
    }

    @Test("이전 달로 옮기면 그 달 구간을 다시 조회한다")
    func showingPreviousMonthRequestsThatMonth() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return []
        })
        await viewModel.loadCalendar()

        await viewModel.showPreviousMonth()

        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 6, day: 1))
        #expect(await recorder.requests.count == 2)
        #expect(await recorder.requests.last?.start == Self.date(year: 2026, month: 5, day: 31))
    }

    @Test("현재 달에서는 다음 달로 넘어갈 수 없다")
    func nextMonthIsBlockedAtTheCurrentMonth() async {
        let viewModel = makeViewModel()

        #expect(viewModel.canShowNextMonth == false)

        await viewModel.showPreviousMonth()

        #expect(viewModel.canShowNextMonth)
    }

    @Test("넘어갈 수 없는 달에서는 다음 달 요청이 아무 일도 하지 않는다")
    func blockedNextMonthDoesNotRequest() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return []
        })
        await viewModel.loadCalendar()

        await viewModel.showNextMonth()

        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 7, day: 1))
        #expect(await recorder.requests.count == 1)
    }

    @Test("달을 옮기면 고른 날이 함께 풀린다")
    func movingMonthClearsTheSelectedDate() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        viewModel.selectDate(PerformanceSampleData.date(at: 3))

        await viewModel.showPreviousMonth()

        #expect(viewModel.selectedDate == nil)

        viewModel.selectDate(PerformanceSampleData.date(at: 3))
        await viewModel.showMonth(year: 2026, month: 4)

        #expect(viewModel.selectedDate == nil)
    }

    @Test("월 점프는 고른 달 구간을 조회한다")
    func jumpingToAMonthRequestsThatMonth() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return []
        })
        await viewModel.loadCalendar()

        await viewModel.showMonth(year: 2026, month: 3)

        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 3, day: 1))
        #expect(await recorder.requests.last?.start == Self.date(year: 2026, month: 2, day: 28))
    }

    @Test("아직 오지 않은 달로는 점프하지 않는다")
    func jumpingToAFutureMonthDoesNothing() async {
        let recorder = TrendRequestRecorder()
        let viewModel = makeViewModel(trend: { start, end, granularity in
            await recorder.record(
                TrendRequest(start: start, end: end, granularity: granularity)
            )
            return []
        })
        await viewModel.loadCalendar()

        await viewModel.showMonth(year: 2026, month: 9)

        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 7, day: 1))
        #expect(await recorder.requests.count == 1)
    }

    @Test("올해는 이번 달 뒤가 비활성이고 지난 해는 열두 달 모두 고를 수 있다")
    func disabledMonthsCoverTheFutureOnly() async {
        let viewModel = makeViewModel()

        #expect(viewModel.displayedYear == 2026)
        #expect(viewModel.displayedMonth == 7)
        #expect(viewModel.disabledMonths == Set(8...12))

        await viewModel.showPreviousYear()

        #expect(viewModel.displayedYear == 2025)
        #expect(viewModel.disabledMonths.isEmpty)
    }

    @Test("올해에서는 다음 해로 넘어갈 수 없다")
    func nextYearIsBlockedAtTheCurrentYear() async {
        let viewModel = makeViewModel()

        #expect(viewModel.canShowNextYear == false)

        await viewModel.showPreviousYear()

        #expect(viewModel.canShowNextYear)
    }

    @Test("해를 넘길 때 아직 오지 않은 달로는 가지 않는다")
    func movingYearClampsToTheLatestSelectableMonth() async {
        let viewModel = makeViewModel()
        await viewModel.showMonth(year: 2025, month: 12)

        await viewModel.showNextYear()

        // 2025년 12월에서 한 해를 넘기면 2026년 12월이 아니라 이번 달(7월)에 선다.
        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 7, day: 1))
    }

    @Test("캘린더 조회 실패가 차트·요약을 오염시키지 않는다")
    func calendarFailureLeavesChartAndSummaryIntact() async {
        // 지수를 요청하지 않는 쪽이 곧 캘린더 조회다.
        let viewModel = makeViewModel(comparison: { _, _, indices in
            guard indices.isEmpty else { return PerformanceSampleData.comparison }
            throw AppError.network("시세 서버 응답 없음")
        })

        await viewModel.refresh()

        #expect(viewModel.calendarState.error != nil)
        #expect(viewModel.trendState.value != nil)
        #expect(viewModel.summaryState.value != nil)
        // 캘린더는 카드 안에서 스스로 실패를 말한다 — 상단 배지를 켜지 않는다.
        #expect(viewModel.isStale == false)
    }

    @Test("기록이 없는 달은 실패가 아니라 빈 결과로 남는다")
    func emptyMonthStaysLoaded() async {
        let viewModel = makeViewModel(
            trend: { _, _, _ in [] },
            comparison: { _, _, _ in BenchmarkComparison(portfolio: [], benchmarks: []) }
        )

        await viewModel.loadCalendar()

        #expect(viewModel.calendarState.value == [])
        #expect(viewModel.calendarState.error == nil)
    }

    @Test("첫 로딩이 캘린더도 채운다")
    func firstLoadFillsCalendar() async {
        let viewModel = makeViewModel()

        await viewModel.refresh()

        // 표본 8개 점 중 7월에 드는 것은 마지막 하나뿐이다.
        #expect(viewModel.calendarState.value?.map(\.date) == [PerformanceSampleData.date(at: 7)])
    }

    @Test("refresh 가 캘린더도 다시 받아온다")
    func refreshReloadsCalendar() async {
        let recorder = ComparisonRequestRecorder()
        let viewModel = makeViewModel(comparison: { start, _, indices in
            await recorder.record(ComparisonRequest(start: start, indices: indices))
            return PerformanceSampleData.comparison
        })
        await viewModel.refresh()

        await viewModel.refresh()

        let calendarRequests = await recorder.requests.filter { $0.indices.isEmpty }
        #expect(calendarRequests.count == 2)
    }

    @Test("달을 빠르게 두 번 넘겨도 나중에 시작한 조회 결과만 반영된다")
    func rapidMonthNavigationKeepsLatestRequestWinning() async {
        // 4월 25일부터 하루 간격 42개 점 — 6월 구간에는 5개, 5월 구간에는 31개가 남는다.
        let dataset = Self.dailySamples(from: Self.date(year: 2026, month: 4, day: 25), count: 42)
        let gate = RequestGate()
        let junePeriodStart = Self.date(year: 2026, month: 5, day: 31)
        let viewModel = makeViewModel(
            trend: { start, end, _ in
                if start == junePeriodStart { await gate.wait() }
                return Self.trendPoints(of: Self.samples(in: dataset, from: start, to: end))
            },
            comparison: { start, end, _ in
                Self.comparison(of: Self.samples(in: dataset, from: start, to: end))
            }
        )

        async let previousMonth: Void = viewModel.showPreviousMonth()
        async let twoMonthsBack: Void = viewModel.showPreviousMonth()
        await twoMonthsBack

        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 5, day: 1))
        #expect(viewModel.calendarState.value?.count == Constants.mayCellCount)

        await gate.signal()
        await previousMonth

        // 6월 조회가 나중에 끝나도 5월 격자를 덮어쓰지 않는다.
        #expect(viewModel.calendarMonth == Self.date(year: 2026, month: 5, day: 1))
        #expect(viewModel.calendarState.value?.count == Constants.mayCellCount)
    }

    // MARK: - Function

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components) ?? .distantPast
    }

    /// 하루 간격으로 누적 등락률이 조금씩 오르는 표본. 캘린더가 며칠치를 받았는지로만
    /// 구분하면 되므로 값 자체에는 의미를 두지 않는다.
    nonisolated private static func dailySamples(
        from start: Date,
        count: Int
    ) -> [(date: Date, rate: Decimal)] {
        (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return (date, Decimal(offset) / Constants.dailyRateDivisor)
        }
    }

    /// 저장소가 하는 일 — 요청한 구간에 드는 기록만 돌려준다.
    nonisolated private static func samples(
        in dataset: [(date: Date, rate: Decimal)],
        from start: Date,
        to end: Date
    ) -> [(date: Date, rate: Decimal)] {
        dataset.filter { $0.date >= start && $0.date <= end }
    }

    nonisolated private static func trendPoints(
        of samples: [(date: Date, rate: Decimal)]
    ) -> [NetWorthTrendPoint] {
        samples.map {
            NetWorthTrendPoint(
                date: $0.date,
                total: .krw(Constants.sampleOpeningTotal * (1 + $0.rate))
            )
        }
    }

    nonisolated private static func comparison(
        of samples: [(date: Date, rate: Decimal)]
    ) -> BenchmarkComparison {
        BenchmarkComparison(
            portfolio: samples.map { BenchmarkPoint(date: $0.date, rate: $0.rate) },
            benchmarks: []
        )
    }

    nonisolated private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func makeViewModel(
        record: @escaping @Sendable (Date) async -> Void = { _ in },
        ytd: @escaping @Sendable (Date) async throws -> YTDReturn? = { _ in
            PerformanceSampleData.ytdReturn
        },
        trend: @escaping @Sendable (Date, Date, TrendGranularity) async throws
            -> [NetWorthTrendPoint] = { _, _, _ in PerformanceSampleData.trendPoints },
        comparison: @escaping @Sendable (Date, Date, [BenchmarkIndex]) async throws
            -> BenchmarkComparison = { _, _, _ in PerformanceSampleData.comparison }
    ) -> PerformanceViewModel {
        PerformanceViewModel(
            recordSnapshotUseCase: StubRecordSnapshotUseCase(onExecute: record),
            calculateYTDReturnUseCase: StubCalculateYTDReturnUseCase(result: ytd),
            fetchNetWorthTrendUseCase: StubFetchNetWorthTrendUseCase(result: trend),
            compareBenchmarkUseCase: StubCompareBenchmarkUseCase(result: comparison),
            exchangeRateService: StubExchangeRateService(),
            calendar: Self.calendar,
            now: { PerformanceSampleData.now }
        )
    }
}

/// 스냅샷 기록과 요약 조회가 **어떤 순서로** 일어났는지 남긴다. 순서가 뒤집히면 첫 종목을
/// 등록한 날 요약이 아직 없는 이력을 읽어 "계산할 성과가 없어요" 로 남는다.
private actor SnapshotCallLog {
    enum Event: Equatable {
        case snapshot
        case summary
    }

    private(set) var events: [Event] = []
    private(set) var recordedDates: [Date] = []

    func recordSnapshot(asOf date: Date) {
        events.append(.snapshot)
        recordedDates.append(date)
    }

    func readSummary() {
        events.append(.summary)
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
    let end: Date
    let granularity: TrendGranularity
}

private actor TrendRequestRecorder {
    private(set) var requests: [TrendRequest] = []

    /// 차트가 낸 조회만. 차트 구간은 언제나 `now` 에서 끝나고(`dateRange(for:now:calendar:)`),
    /// 캘린더는 그 달 말일 23:59:59 에서 끝나므로 종료 시각으로 둘을 가른다.
    var chartRequests: [TrendRequest] {
        requests.filter { $0.end == PerformanceSampleData.now }
    }

    func record(_ request: TrendRequest) {
        requests.append(request)
    }
}

/// 어떤 지수를 함께 요청했는지 남긴다. 캘린더 조회는 지수를 하나도 달지 않으므로
/// `indices.isEmpty` 가 곧 "이건 캘린더 조회다" 라는 표식이 된다.
private struct ComparisonRequest: Equatable, Sendable {
    let start: Date
    let indices: [BenchmarkIndex]
}

private actor ComparisonRequestRecorder {
    private(set) var requests: [ComparisonRequest] = []

    func record(_ request: ComparisonRequest) {
        requests.append(request)
    }
}

/// 스텁 클로저 하나를 원하는 시점까지 붙잡아 두는 문. 두 조회가 겹칠 때 어느 쪽이
/// 먼저 끝나는지를 테스트가 직접 정하기 위해 쓴다.
///
/// 열린 상태를 기억한다 — 붙잡을 조회가 아직 문 앞에 오지 않았을 때 `signal()` 이 들어와도
/// 그 신호를 흘리지 않기 위해서다. 흘리면 뒤늦게 도착한 `wait()` 이 영영 깨지 않아
/// 테스트가 실패가 아니라 **정지**한다.
private actor RequestGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func signal() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

/// `AppError` 로 매핑되지 않는 에러가 들어오는 경로를 확인하기 위한 표본.
private struct SampleFailure: Error {}

fileprivate enum Constants {
    static let expectedExcessReturn = Decimal(string: "0.043") ?? 0
    /// 화면에는 0.1%p 까지만 찍히므로 그보다 잘게 따질 이유가 없다.
    static let excessReturnTolerance = Decimal(string: "0.0001") ?? 0
    /// 2026년 5월은 31일. 6월 구간(5개)과 자릿수부터 달라 어느 달의 결과가 남았는지 구분된다.
    static let mayCellCount = 31
    /// 하루마다 0.1%p 씩 올리는 분모. 값 자체는 테스트 판정에 쓰지 않는다.
    static let dailyRateDivisor: Decimal = 1_000
    static let sampleOpeningTotal: Decimal = 120_000_000
}
