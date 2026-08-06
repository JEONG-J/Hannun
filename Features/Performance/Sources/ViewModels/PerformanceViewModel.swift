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

    /// 차트와 액세서리가 지금 말하는 단위. 액세서리 오른쪽 컨트롤이 뒤집는다.
    private(set) var valueUnit: PerformanceValueUnit = Constants.initialValueUnit

    /// 캘린더에서 고른 날. 다음 선택이나 월 이동 전까지 남는다.
    private(set) var selectedDate: Date?

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

    /// 기간 구간 시트가 떠 있는지. 기간 메뉴의 "직접 선택…" 이 연다.
    var isPeriodRangePickerPresented = false

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

    /// 화면이 "지금 보고 있는" 시점.
    ///
    /// 두 선택을 **합치지 않고 겹친다**. 스크럽은 손을 떼면 사라지는 일시 값이고 캘린더
    /// 선택은 다음 조작까지 남는 지속 값이라, 하나로 합치면 스크럽이 끝나는 순간
    /// (`scrubbedDate = nil`) 캘린더 선택까지 함께 지워진다. 겹쳐 두면 손을 뗀 뒤 캘린더
    /// 선택으로 돌아오는 코드를 따로 쓰지 않아도 된다.
    var focusedDate: Date? { scrubbedDate ?? selectedDate }

    /// 차트가 실제로 그릴 커서 위치. 차트가 그 시점을 담고 있지 않으면 `nil` 이다.
    var chartCursorDate: Date? { focusedPoint?.date }

    /// 다음 달로 넘어갈 수 있는지. 아직 오지 않은 달에는 칠할 기록이 없다.
    var canShowNextMonth: Bool {
        guard let currentMonth = Self.startOfMonth(now(), calendar: calendar) else { return false }
        return calendarMonth < currentMonth
    }

    /// 다음 해로 넘어갈 수 있는지. 월 점프 격자가 년 이동 화살표에 쓴다.
    var canShowNextYear: Bool {
        displayedYear < currentYear
    }

    /// 월 점프 격자에서 고를 수 없는 달.
    ///
    /// **미래 달만 막는다.** "기록이 없는 달"까지 막으려면 첫 스냅샷 날짜를 알아야 하고 그건
    /// ALL 구간 조회를 한 번 더 태워야 한다 — 들어가 봐야 이미 있는 "이 달에는 기록이 없어요"
    /// 가 말해 주므로 그 비용을 쓰지 않는다.
    var disabledMonths: Set<Int> {
        disabledMonths(inYear: displayedYear)
    }

    /// 캘린더가 보고 있는 년. 월 점프 격자의 헤더와 비활성 계산이 함께 쓴다.
    var displayedYear: Int {
        calendar.component(.year, from: calendarMonth)
    }

    /// 캘린더가 보고 있는 달의 번호(1~12).
    var displayedMonth: Int {
        calendar.component(.month, from: calendarMonth)
    }

    /// 올해. 년 점프 격자가 가장 최신 페이지의 끝을 이 값으로 잡는다 — 주입된 시계를 함께
    /// 써야 프리뷰·테스트에서 격자와 비활성 계산이 같은 "오늘" 을 본다.
    var currentYear: Int {
        calendar.component(.year, from: now())
    }

    /// 상단 큰 숫자. 보고 있는 시점이 있으면 그 값이 연초 대비 값을 대신한다.
    var headline: PerformanceHeadline? {
        if let focusedHeadline { return focusedHeadline }
        guard
            let summary = summaryState.value,
            case let .calculated(rate, gain) = summary
        else { return nil }

        return PerformanceHeadline(focusedDate: nil, rate: rate, amount: gain)
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

    /// 차트에 겹칠 벤치마크. 비교가 꺼져 있거나 선택이 없거나 조회에 실패한 지수면
    /// 아무것도 그리지 않는다.
    ///
    /// **금액 축을 그리는 동안에도 아무것도 내주지 않는다.** 지수는 등락률이라 원화 축에
    /// 얹으면 두 선의 기울기가 서로 무관해진다 (UI 스펙 §4.3 오버레이 규칙). 여기 한 곳만
    /// 막으면 차트 오버레이와 액세서리의 초과수익 문구가 함께 사라진다 — 호출부마다 분기하면
    /// 언젠가 한쪽만 남는다.
    var overlaidBenchmark: BenchmarkSeries? {
        guard valueUnit == .percent, isBenchmarkOverlayEnabled, let selectedBenchmark else {
            return nil
        }

        return trendState.value?.benchmarks.first { $0.index == selectedBenchmark }
    }

    /// 추이 마지막 시점의 총자산. 액세서리 왼쪽이 히어로가 보이는 동안 말하는 값이다.
    ///
    /// `totals` 는 딕셔너리라 순서가 없어 가장 늦은 날짜로 고른다. 추이가 아직 없거나 그
    /// 구간에 기록이 없으면 `nil` 이고, 그때 액세서리는 아래 대역으로 흘러간다.
    var latestTotal: Money? {
        trendState.value?.totals.max { $0.key < $1.key }?.value
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

    /// `focusedDate` 에 대응하는 차트 점. 없으면 차트가 그 시점을 담고 있지 않다는 뜻이다.
    ///
    /// 단위별로 매칭을 다르게 하는 이유: 캘린더에서 온 `focusedDate` 는 언제나 **하루**지만
    /// 차트는 월별 단위면 달마다 점 하나로 샘플링돼 있다. 날짜를 그대로 비교하면 월별에서는
    /// 어떤 날을 골라도 커서가 뜨지 않는다.
    ///
    /// 차트가 담지 않은 시점(3년 전 달의 셀 같은)이면 `nil` 이고, 그 상태가 곧 "차트는
    /// 가만히 둔다" 다 — 기간을 자동으로 넓히지 않으므로 별도 분기가 필요 없다.
    private var focusedPoint: BenchmarkPoint? {
        guard let focusedDate, let trend = trendState.value else { return nil }

        return trend.portfolio.first { point in
            switch granularity {
            case .daily:
                calendar.isDate(point.date, inSameDayAs: focusedDate)
            case .monthly:
                calendar.isDate(point.date, equalTo: focusedDate, toGranularity: .month)
            }
        }
    }

    private var focusedHeadline: PerformanceHeadline? {
        guard let point = focusedPoint, let trend = trendState.value else { return nil }

        return PerformanceHeadline(
            focusedDate: point.date,
            rate: point.rate,
            amount: trend.totals[point.date]
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
    ///
    /// 앱을 안 켠 날은 추이 조회에서 `isCarriedForward` 로 표시돼 온다. 그 날짜를 모아
    /// `DailyReturn.series` 에 넘기면 캘린더에서만 빠진다 — 차트는 같은 점을 그대로 그린다.
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
            let series = DailyReturn.series(
                cumulative: comparison.portfolio,
                totals: totals,
                carriedForwardDates: Set(points.filter(\.isCarriedForward).map(\.date))
            )

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
        guard
            let month = calendar.date(byAdding: .month, value: -1, to: calendarMonth)
        else { return }

        await setMonth(month)
    }

    /// 화살표가 이미 `.disabled` 지만 guard 로 우회까지 막는다.
    func showNextMonth() async {
        guard
            canShowNextMonth,
            let month = calendar.date(byAdding: .month, value: 1, to: calendarMonth)
        else { return }

        await setMonth(month)
    }

    /// 월 점프 격자가 부른다. 년·월을 직접 받으므로 ◀▶ 를 열일곱 번 누를 일이 없다.
    ///
    /// 격자가 이미 미래 달을 `.disabled` 로 두지만 guard 로 우회까지 막는다.
    func showMonth(year: Int, month: Int) async {
        guard
            month <= latestSelectableMonth(inYear: year),
            let target = calendar.date(from: DateComponents(year: year, month: month))
        else { return }

        await setMonth(target)
    }

    /// 년 점프 격자가 부르는 진입점 — 해를 옮겨도 보고 있던 달을 그대로 유지한다.
    ///
    /// 다만 옮긴 해에서 그 달이 아직 오지 않았다면 그 해의 마지막 유효한 달로 당긴다. 그러지
    /// 않으면 한 걸음에 미래로 넘어가 격자가 전부 비활성인 채 "기록이 없어요" 만 뜬다.
    ///
    /// 미래 해는 고를 수 있는 달이 아예 없어(`0`) guard 에 걸린다 — 격자가 미래 연도를
    /// 그리지 않지만, 0 을 그대로 넘기면 `DateComponents` 가 전 해 12월로 굴러간다.
    func showYear(_ year: Int) async {
        let month = min(displayedMonth, latestSelectableMonth(inYear: year))

        guard
            month > 0,
            let target = calendar.date(from: DateComponents(year: year, month: month))
        else { return }

        await setMonth(target)
    }

    /// 월 점프 격자가 펼쳐진 동안 ◀▶ 가 부른다.
    func showPreviousYear() async {
        await showYear(displayedYear - 1)
    }

    func showNextYear() async {
        guard canShowNextYear else { return }
        await showYear(displayedYear + 1)
    }

    /// 캘린더 셀 탭의 유일한 진입점. 같은 날을 다시 누르면 선택이 풀린다 — 펼친 상세 줄을
    /// 닫을 다른 손잡이를 만들지 않는다.
    func selectDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDate = selectedDate.map { calendar.startOfDay(for: $0) } == day ? nil : day
    }

    /// 차트 카드의 기간 세그먼트가 부른다.
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

    /// 액세서리 오른쪽 컨트롤이 부른다. 축만 바꾸므로 재조회하지 않는다 — 시점별 총자산은
    /// 이미 `trend.totals` 에 들어 있다.
    func toggleValueUnit() {
        valueUnit = valueUnit.toggled
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

    /// 그 해에서 고를 수 없는 달. 캘린더 카드의 월 점프 격자와 기간 구간 시트가 함께 쓴다 —
    /// 두 격자가 같은 달을 놓고 서로 다른 답을 내면 안 되므로 규칙을 여기 하나만 둔다.
    func disabledMonths(inYear year: Int) -> Set<Int> {
        let latest = latestSelectableMonth(inYear: year)
        guard latest < Constants.monthsPerYear else { return [] }

        return Set((latest + 1)...Constants.monthsPerYear)
    }

    /// 아직 받아오기 전에는 전부 활성으로 둔다 — 없다고 단정할 근거가 없다.
    func isBenchmarkAvailable(_ index: BenchmarkIndex) -> Bool {
        guard let trend = trendState.value else { return true }
        return !trend.unavailableIndices.contains(index)
    }

    /// 기간 메뉴가 고른 구간. `.all` 은 첫 기록 시점을 알 수 없어 하한을 두지 않는다.
    ///
    /// 종료 시각까지 함께 고르는 건 `.custom` 뿐이다 — 프리셋은 전부 "지금까지" 라서
    /// `now` 로 끝난다.
    static func dateRange(
        for period: ChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let range: (start: Date?, end: Date) = switch period {
        case .oneMonth:
            (calendar.date(byAdding: .month, value: -1, to: now), now)
        case .threeMonths:
            (calendar.date(byAdding: .month, value: -3, to: now), now)
        case .sixMonths:
            (calendar.date(byAdding: .month, value: -6, to: now), now)
        case .yearToDate:
            (calendar.date(from: calendar.dateComponents([.year], from: now)), now)
        case .oneYear:
            (calendar.date(byAdding: .year, value: -1, to: now), now)
        case .all:
            (Date.distantPast, now)
        case let .custom(start, end):
            (start, end)
        }

        return (range.start ?? .distantPast, range.end)
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

    /// 그 해에서 고를 수 있는 마지막 달. 지난 해는 12월까지, 올해는 이번 달까지다.
    private func latestSelectableMonth(inYear year: Int) -> Int {
        if year < currentYear { return Constants.monthsPerYear }
        if year > currentYear { return 0 }
        return calendar.component(.month, from: now())
    }

    /// ◀▶ 와 월 점프가 함께 쓰는 진입점 — 선택 해제·로딩 표시·재조회를 한 곳에서 한다.
    ///
    /// 옮긴 달의 값을 받아오기 전까지 이전 달 셀을 화면에 남기지 않는다 — 라벨은 새 달인데
    /// 격자는 옛 달이면 잠깐이라도 거짓말을 하는 화면이 된다. 고른 날도 함께 푼다: 지난
    /// 달 날짜를 가리키는 상세 줄이 새 격자 아래 남으면 안 된다.
    private func setMonth(_ month: Date) async {
        calendarMonth = month
        selectedDate = nil
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
    static let initialValueUnit: PerformanceValueUnit = .percent
    static let monthsPerYear = 12
}
