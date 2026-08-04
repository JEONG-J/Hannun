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

    /// 캘린더가 보고 있는 달의 1일.
    ///
    /// 차트의 `period`/`granularity` 와 **완전히 분리한다**. 차트 상태에 매달면 월별 토글을
    /// 켠 순간 캘린더가 월 단위로 샘플링된 점을 받아 "전월 대비" 수익률을 일별 격자에 칠하게
    /// 된다 — 값이 조용히 전부 틀리고 에러도 나지 않는다.
    private(set) var calendarMonth: Date
    private(set) var calendarState: Loadable<[DailyReturn]> = .idle

    private(set) var period: ChartPeriod = Constants.initialPeriod
    private(set) var granularity: TrendGranularity = Constants.initialGranularity
    private(set) var selectedBenchmark: BenchmarkIndex?

    /// 스크럽 중인 시점. 차트가 직접 갱신하므로 바인딩할 수 있어야 한다.
    var scrubbedDate: Date? {
        didSet {
            if scrubbedDate != nil { hasScrubbed = true }
        }
    }

    /// 한 번이라도 스크럽했는지. `scrubbedDate` 는 손을 떼면 `nil` 로 돌아가지만 이 값은
    /// 그대로 남아 — 한 번 배운 조작을 다시 안내하지 않기 위해서다.
    private(set) var hasScrubbed = false

    /// 고른 지수를 차트에 실제로 겹칠지.
    ///
    /// **무엇을 비교할지(`selectedBenchmark`)와 비교할지 말지를 분리한다.** 액세서리
    /// 오른쪽 컨트롤이 껐다 켜도 고른 지수는 남아 있어야 다시 켤 때 그대로 돌아온다.
    /// 하나로 합치면 끄는 순간 선택이 사라져 매번 다시 고르게 된다.
    private(set) var isBenchmarkOverlayEnabled = false

    /// 벤치마크 선택 시트가 떠 있는지. 툴바 아이콘을 눌러 연다 (디자인 문서 §7).
    var isBenchmarkPickerPresented = false

    /// 기간 선택 시트가 떠 있는지. 액세서리 왼쪽 캡션을 눌러 연다.
    var isPeriodPickerPresented = false

    /// 본문 헤드라인이 아직 화면에 있는지. 액세서리 왼쪽이 무엇을 말할지를 이 값이 정한다.
    var isHeroVisible = true

    private(set) var isSummaryStale = false
    private(set) var isTrendStale = false

    /// `loadTrend()` 를 부를 때마다 하나씩 늘어난다. 기간·단위 컨트롤은 재탭마다 값을 뒤집는
    /// 전환형이라(구 `GranularityToggle` 세그먼트처럼 같은 값 재탭이 걸러지지 않는다) 빠르게
    /// 두 번 누르면 두 조회가 동시에 떠 있을 수 있다 — 나중에 **끝난** 쪽이 아니라 나중에
    /// **시작한** 쪽 결과만 반영해야 라벨(`granularity`)과 차트(`trendState`)가 어긋나지 않는다.
    private var trendRequestID = 0

    /// `loadCalendar()` 판 세대 토큰. 월 이동 화살표도 재탭이 걸러지지 않는 전환형이라
    /// ◀ ◀ 를 빠르게 두 번 누르면 두 조회가 겹친다 — 먼저 시작한 쪽이 나중에 끝나면 7월 셀이
    /// 6월 라벨 아래 남는다. `trendRequestID` 와 같은 이유로 따로 둔다(차트와 캘린더는 서로의
    /// 요청을 무효로 만들면 안 되므로 토큰을 공유하지 않는다).
    private var calendarRequestID = 0

    private let calculateYTDReturnUseCase: any CalculateYTDReturnUseCaseProtocol
    private let fetchNetWorthTrendUseCase: any FetchNetWorthTrendUseCaseProtocol
    private let compareBenchmarkUseCase: any CompareBenchmarkUseCaseProtocol
    private let exchangeRateService: any ExchangeRateServiceProtocol
    private let calendar: Calendar
    private let now: () -> Date

    /// 마지막 값을 지운 채 실패로 떨어졌는지 여부. 갱신 실패는 배지로만 알린다 (UI 스펙 §4).
    ///
    /// 캘린더 실패는 여기 들어오지 않는다 — 캘린더는 카드 안에서 직접 실패를 말한다.
    var isStale: Bool { isSummaryStale || isTrendStale }

    /// 다음 달로 넘어갈 수 있는지. 아직 오지 않은 달에는 칠할 기록이 없다.
    var canShowNextMonth: Bool {
        guard let currentMonth = Self.startOfMonth(now(), calendar: calendar) else { return false }
        return calendarMonth < currentMonth
    }

    /// 상단 큰 숫자. 스크럽 중이면 그 시점 값이 연초 대비 값을 대신한다.
    var headline: PerformanceHeadline? {
        if let scrubbedHeadline { return scrubbedHeadline }
        guard
            let summary = summaryState.value,
            case let .calculated(rate, gain) = summary
        else { return nil }

        return PerformanceHeadline(scrubbedDate: nil, rate: rate, amount: gain)
    }

    /// 요약도 추이도 그릴 값이 하나도 없는 상태.
    ///
    /// 둘 다 확인하는 이유: 연초 기록만 없고 그 이전 기록은 있을 수 있다(기간을 1Y 로 두면
    /// 작년 구간이 그려진다). 그 경우 YTD 만 못 낼 뿐 차트는 멀쩡하므로 감추면 안 된다.
    /// 추이가 아직 로딩 중일 때도 감추지 않는다 — 잠깐 사라졌다 나타나는 깜빡임이 생긴다.
    var hasNoRecords: Bool {
        guard
            case .loaded(.insufficientData) = summaryState,
            case let .loaded(trend) = trendState
        else { return false }

        return trend.portfolio.count < 2
    }

    /// 스크럽 가이드 한 줄을 보여줄지. 한 번이라도 스크럽했거나, 추이가 아직 로딩·실패
    /// 중이거나, 점이 하나뿐이라 스크럽할 대상이 없으면(그 경우 `insufficientDataNotice` 가
    /// 대신 뜬다) 안내할 이유가 없다.
    var isScrubHintVisible: Bool {
        guard case let .loaded(trend) = trendState else { return false }
        return !hasScrubbed && trend.portfolio.count > 1
    }

    /// 액세서리 왼쪽이 기본으로 말하는 한 줄 — "YTD · 일별". 기간과 단위를 한 곳에서 고치므로
    /// 무엇이 바뀌어도 이 문구만 다시 읽으면 된다.
    var periodSummary: String {
        "\(period.title) · \(granularity.title)"
    }

    /// 차트에 겹칠 벤치마크. 비교가 꺼져 있거나 선택이 없거나 조회에 실패한 지수면
    /// 아무것도 그리지 않는다.
    var overlaidBenchmark: BenchmarkSeries? {
        guard isBenchmarkOverlayEnabled, let selectedBenchmark else { return nil }
        return trendState.value?.benchmarks.first { $0.index == selectedBenchmark }
    }

    /// 액세서리 한 줄이 말하는 초과수익 — "S&P500 대비 +1.4%p".
    ///
    /// 내 수익률과 지수 등락률 둘 다 **기간 시작을 0 으로** 정규화한 값이라 그대로 빼면
    /// 백분율 포인트 차가 된다. 비율끼리의 나눗셈이 아니므로 단위는 `%` 가 아니라 `%p` 다.
    var benchmarkExcessReturn: Decimal? {
        guard
            let series = overlaidBenchmark,
            let mine = trendState.value?.portfolio.last?.rate,
            let theirs = series.points.last?.rate
        else { return nil }

        return mine - theirs
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
        exchangeRateService: any ExchangeRateServiceProtocol,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.calculateYTDReturnUseCase = calculateYTDReturnUseCase
        self.fetchNetWorthTrendUseCase = fetchNetWorthTrendUseCase
        self.compareBenchmarkUseCase = compareBenchmarkUseCase
        self.exchangeRateService = exchangeRateService
        self.calendar = calendar
        self.now = now
        calendarMonth = Self.startOfMonth(now(), calendar: calendar) ?? now()
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
            ),
            exchangeRateService: container.resolve((any ExchangeRateServiceProtocol).self)
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
        await loadCalendar()
    }

    /// 캘린더 한 달치를 받아온다. 차트가 어떤 기간·단위를 보고 있든 **항상 일별 한 달**이다.
    ///
    /// 조회 구간이 그 달 1일이 아니라 **하루 전**부터인 이유: 1일의 일간 수익률은 전날 총자산이
    /// 있어야 낼 수 있다. 그래서 하루를 더 받아 파생한 뒤, 그 하루는 결과에서 다시 걷어낸다.
    func loadCalendar() async {
        if calendarState.value == nil { calendarState = .loading }

        calendarRequestID += 1
        let requestID = calendarRequestID

        let month = calendarMonth
        let range = Self.calendarRange(for: month, calendar: calendar)
        let exchangeRate = await exchangeRateService.currentRate()

        do {
            let points = try await fetchNetWorthTrendUseCase.execute(
                from: range.start,
                to: range.end,
                granularity: .daily,
                baseCurrency: Constants.baseCurrency
            )
            // 지수는 하나도 요청하지 않는다 — `CompareBenchmarkUseCase` 의 지수 루프가
            // `indices` 를 그대로 순회하므로 빈 배열이면 벤치마크 저장소를 아예 건드리지
            // 않는다. 캘린더에는 내 수익률만 필요하다.
            let comparison = try await compareBenchmarkUseCase.execute(
                from: range.start,
                to: range.end,
                indices: [],
                baseCurrency: Constants.baseCurrency,
                exchangeRate: exchangeRate
            )

            guard requestID == calendarRequestID else { return }

            let totals = Dictionary(
                points.map { ($0.date, $0.total) },
                uniquingKeysWith: { _, latest in latest }
            )
            let series = DailyReturn.series(cumulative: comparison.portfolio, totals: totals)

            calendarState = .loaded(series.filter { isInDisplayedMonth($0.date, month: month) })
        } catch {
            guard requestID == calendarRequestID else { return }
            // 마지막 값을 남기지 않는다. 캘린더 실패는 `isStale` 배지를 켜지 않기로 했으므로
            // 값만 남기면 낡은 달의 셀이 아무 표시 없이 최신인 척 남는다 — 카드 안 실패 상태와
            // "다시 시도" 로 있는 그대로 말하는 편이 정직하다.
            calendarState = .failed(AppError(narrowing: error))
        }
    }

    func showPreviousMonth() async {
        await showMonth(offsetBy: -1)
    }

    /// 화살표가 이미 `.disabled` 지만 guard 로 우회까지 막는다.
    func showNextMonth() async {
        guard canShowNextMonth else { return }
        await showMonth(offsetBy: 1)
    }

    /// 기간 선택 시트가 부른다. 고른 값과 무관하게 시트를 닫는다 — 이미 보고 있던 기간을
    /// 다시 눌러도 "골랐다"는 사용자 의도는 같다.
    func selectPeriod(_ period: ChartPeriod) async {
        isPeriodPickerPresented = false
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

    /// 액세서리 오른쪽 단위 토글. `.daily` ↔ `.monthly` 를 오가며 기존 `selectGranularity(_:)` 를
    /// 그대로 불러 재조회·스크럽 해제 규칙을 다시 구현하지 않는다.
    func toggleGranularity() async {
        await selectGranularity(granularity == .daily ? .monthly : .daily)
    }

    /// 같은 지수를 다시 고르면 선택이 풀린다 — 겹칠 벤치마크는 0~1개다 (UI 스펙 §4.3).
    func toggleBenchmark(_ index: BenchmarkIndex) {
        selectBenchmark(selectedBenchmark == index ? nil : index)
    }

    /// 지수를 고르면 비교도 함께 켠다 — 골라 놓고 아무 일도 일어나지 않으면 시트를 닫은
    /// 사용자는 선택이 먹지 않았다고 읽는다. 선택을 푸는 경우에만 함께 끈다.
    func selectBenchmark(_ index: BenchmarkIndex?) {
        selectedBenchmark = index
        isBenchmarkOverlayEnabled = index != nil
    }

    /// 벤치마크 선택 시트 안 "차트에 겹치기" 스위치가 부른다. 시트가 이미 떠 있는 상태에서만
    /// 눌리므로 예전처럼 선택 시트를 여는 분기는 필요 없다. 고른 지수가 없으면 스위치 자체가
    /// `.disabled(true)` 라 눌리지 않지만, guard 는 그 우회까지 막아 둔다.
    func toggleBenchmarkOverlay() {
        guard selectedBenchmark != nil else { return }
        isBenchmarkOverlayEnabled.toggle()
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

    /// 캘린더가 조회할 구간 — **그 달 1일의 하루 전 ~ 말일 끝**.
    ///
    /// 하한을 하루 당기는 것이 이 함수의 존재 이유다. 1일부터 받으면 1일이 기준점(첫 점)이
    /// 되어 `DailyReturn.series` 가 그날을 통째로 버린다 — 매달 1일 셀이 영영 비어 보인다.
    /// 상한을 말일 자정이 아니라 **하루 끝**으로 두는 이유는 저장소가 `recordedOn <= end` 로
    /// 걸러서다. 자정으로 두면 말일 낮에 찍힌 스냅샷이 구간 밖으로 밀려난다.
    static func calendarRange(for month: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = calendar.date(byAdding: .day, value: -1, to: month) ?? month
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
        let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) ?? nextMonth

        return (start, end)
    }

    static func startOfMonth(_ date: Date, calendar: Calendar) -> Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
    }

    /// 옮긴 달의 값을 받아오기 전까지 이전 달 셀을 화면에 남기지 않는다 — 라벨은 새 달인데
    /// 격자는 옛 달이면 잠깐이라도 거짓말을 하는 화면이 된다.
    private func showMonth(offsetBy months: Int) async {
        guard let month = calendar.date(byAdding: .month, value: months, to: calendarMonth) else {
            return
        }

        calendarMonth = month
        calendarState = .loading
        await loadCalendar()
    }

    /// 전일 총자산을 얻으려 더 받아온 하루(그리고 하루에 기록이 둘 이상이라 생긴 그 달 밖의
    /// 파생값)를 걷어낸다.
    private func isInDisplayedMonth(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    private func loadSummary() async {
        if summaryState.value == nil { summaryState = .loading }

        do {
            let ytdReturn = try await calculateYTDReturnUseCase.execute(
                asOf: now(),
                baseCurrency: Constants.baseCurrency,
                exchangeRate: await exchangeRateService.currentRate()
            )
            summaryState = .loaded(PerformanceSummary(ytdReturn))
            isSummaryStale = false
        } catch {
            summaryState = retaining(summaryState, after: error, markingStale: &isSummaryStale)
        }
    }

    private func loadTrend() async {
        if trendState.value == nil { trendState = .loading }

        trendRequestID += 1
        let requestID = trendRequestID

        let range = Self.dateRange(for: period, now: now(), calendar: calendar)
        let indices = BenchmarkIndex.allCases
        let exchangeRate = await exchangeRateService.currentRate()

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
                exchangeRate: exchangeRate
            )

            // 이 사이 더 최신 요청이 떴다면 지금 손에 든 결과는 낡은 것이다 — 나중에 끝나도
            // 반영하지 않는다. 그래야 화면에 남는 값은 항상 사용자의 **마지막** 조작과 맞는다.
            guard requestID == trendRequestID else { return }

            trendState = .loaded(
                PerformanceTrend(
                    requesting: indices,
                    sampledPoints: sampledPoints,
                    comparison: comparison
                )
            )
            isTrendStale = false
        } catch {
            guard requestID == trendRequestID else { return }
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
            return .failed(AppError(narrowing: error))
        }

        isStale = true
        return .loaded(cached)
    }
}

fileprivate enum Constants {
    static let baseCurrency: Currency = .krw
    static let initialPeriod: ChartPeriod = .yearToDate
    static let initialGranularity: TrendGranularity = .daily
}
