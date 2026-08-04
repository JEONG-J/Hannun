# 성과 탭 — 날짜 선택 확장과 액세서리 역할 교체

- 작성일: 2026-08-04
- 상태: 승인됨 (구현 계획 수립 대기)
- 관련 기능: PM-2, PM-4
- 관련 문서: `docs/design/2026-07-27-ui-design-spec.md` §3.1 · §4.3 · §7

## 1. 배경

성과 탭은 지금 이렇게 생겼다.

- **본문**: YTD 히어로 → 차트 카드(범례 + 플롯 + 스크럽 안내) → 월간 수익률 캘린더 카드
- **액세서리**: leading = `YTD · 일별` 캡션(탭 → 기간 시트), trailing = 일별/월별 전환 하나
- **툴바**: 벤치마크 아이콘 하나 → 선택 시트(지수 고르기 + "차트에 겹치기" 스위치)

여기에 두 가지 불만이 있다.

1. **캘린더의 날짜 선택이 반쪽이다.** 셀을 누르면 카드 안에 상세 한 줄이 펼쳐지지만, 어느
   셀을 골랐는지 격자에 표시가 없고, 고른 날이 화면의 다른 요소(히어로·차트)에는 아무
   영향도 주지 않는다. 달 이동도 ◀▶ 한 칸씩뿐이라 작년 3월을 보려면 17번 눌러야 한다.
2. **액세서리가 맡은 일이 차트에 붙어 있어야 할 일이다.** 일별/월별은 차트 축을 바꾸는
   컨트롤인데 화면 하단 캡슐에 떨어져 있다. 그 자리를 비워 더 나은 일을 시키고 싶다.

## 2. 목표

- 캘린더에서 고른 날짜가 **화면 전체의 기준 시점**이 된다 — 히어로 숫자와 차트 커서가 따라온다
- 고른 셀이 격자에서 **눈에 보인다**
- **임의의 달로 한 번에 점프**할 수 있다
- 일별/월별 단위 컨트롤이 **차트 카드 안**으로 들어간다
- 비워진 액세서리 trailing 이 **벤치마크 비교 on/off** 를 맡는다

### 하지 않는 것

- 선택한 날의 상세를 카테고리별 변동·연결된 매매일지까지 넓히지 않는다 (별도 과제)
- 차트 스크럽이 캘린더 선택을 역방향으로 갱신하지 않는다 (§3.4 근거)
- 캘린더가 차트의 기간·단위를 자동으로 바꾸지 않는다 (§3.3 근거)

## 3. 상태 모델

### 3.1 두 선택을 합치지 않고 겹친다

캘린더 선택과 차트 스크럽은 성격이 다르다. 스크럽은 손을 떼면 사라지는 **일시** 값이고,
캘린더 선택은 다음 조작까지 남아 있어야 하는 **지속** 값이다. 하나로 합치면 스크럽이 끝나는
순간(`scrubbedDate = nil`) 캘린더 선택까지 함께 지워진다.

```swift
/// 캘린더에서 고른 날. 다음 선택이나 월 이동 전까지 남는다.
private(set) var selectedDate: Date?

/// 스크럽 중인 시점 (기존). 손을 떼면 nil 로 돌아간다.
var scrubbedDate: Date? { didSet { if scrubbedDate != nil { hasScrubbed = true } } }

/// 화면이 "지금 보고 있는" 시점. 스크럽이 캘린더 선택을 덮되 지우지 않는다.
var focusedDate: Date? { scrubbedDate ?? selectedDate }
```

스크럽에서 손을 떼면 `focusedDate` 가 자동으로 캘린더 선택으로 되돌아온다 — 되돌리는 코드를
따로 쓰지 않는다.

### 3.2 차트 점으로 스냅한다

`focusedDate` 는 캘린더에서 오면 **하루**(일별)지만, 차트는 기간·단위에 따라 월 단위로
샘플링돼 있을 수 있다. 그래서 차트 점을 찾을 때 단위별로 다르게 매칭한다.

```swift
/// `focusedDate` 에 대응하는 차트 점. 없으면 차트가 그 시점을 담고 있지 않다는 뜻이다.
private var focusedPoint: BenchmarkPoint? {
    guard let focusedDate, let trend = trendState.value else { return nil }
    return trend.portfolio.first { point in
        switch granularity {
        case .daily:   calendar.isDate(point.date, inSameDayAs: focusedDate)
        case .monthly: calendar.isDate(point.date, equalTo: focusedDate, toGranularity: .month)
        }
    }
}

/// 차트가 실제로 그릴 커서 위치.
var chartCursorDate: Date? { focusedPoint?.date }
```

`headline` 은 `scrubbedHeadline` 대신 `focusedPoint` 를 본다. 스크럽·캘린더 선택 어느 쪽이든
계산 경로가 하나다.

`TrendLineChart` 에는 계산 바인딩을 넘긴다 — 읽기는 커서, 쓰기는 스크럽이다.

```swift
Binding(
    get: { viewModel.chartCursorDate },
    set: { viewModel.scrubbedDate = $0 }
)
```

### 3.3 구간 밖 선택은 차트를 건드리지 않는다

캘린더는 차트의 기간·단위와 **완전히 분리**돼 있다(`PerformanceViewModel.calendarMonth`
주석). 3년 전 달에서 셀을 고르면 YTD 차트에는 그 점이 없다.

그때 **차트는 가만히 둔다** — 헤드라인은 연초 대비 값 그대로, 커서도 뜨지 않고, 캘린더
상세 한 줄만 갱신된다. 기간을 자동으로 넓히지 않는 이유는 사용자가 시키지 않은 재조회가
따라붙고 직접 고른 기간이 조용히 덮어쓰이기 때문이다. `focusedPoint == nil` 이 곧 이 상태라
별도 분기가 필요 없다.

### 3.4 스크럽은 캘린더를 되돌려 갱신하지 않는다

차트를 쓸면 `scrubbedDate` 가 드래그 내내 매 프레임 바뀐다. 이걸 캘린더 선택으로 흘려보내면
스크럽 한 번에 `calendarMonth` 가 여러 번 바뀌고 그때마다 `loadCalendar()` 가 뜬다. 동기화는
**캘린더 → 차트 단방향**이다.

### 3.5 선택을 푸는 시점

캘린더 셀 탭은 ViewModel 의 진입점 하나를 부른다 — 같은 날을 다시 누르면 풀린다.

```swift
/// 같은 날을 다시 누르면 선택이 풀린다 — 펼친 상세 줄을 닫을 다른 손잡이를 만들지 않는다.
func selectDate(_ date: Date) {
    let day = calendar.startOfDay(for: date)
    selectedDate = selectedDate.map { calendar.startOfDay(for: $0) } == day ? nil : day
}
```

| 사건 | `selectedDate` | 근거 |
|------|---------------|------|
| 같은 셀 재탭 | `nil` | 펼친 상세 줄을 닫을 다른 손잡이를 만들지 않는다 (기존 규칙) |
| 월 이동 (◀▶·월 점프) | `nil` | 지난 달 날짜를 가리키는 상세 줄이 남으면 안 된다 (기존 규칙) |
| 기간 변경 | **유지** | 캘린더 선택은 캘린더의 상태다 |
| 단위 변경 | **유지** | 월별로 바뀌면 §3.2 가 알아서 월 점으로 스냅한다 |
| 새로고침 | **유지** | 같은 날을 계속 보고 있는 것이 사용자의 의도다 |

기존 `MonthlyReturnCard` 의 `@State selectedCell` 과 `.onChange(of: calendarMonth)` 는
ViewModel 로 승격되어 사라진다.

### 3.6 헤드라인 어휘

캘린더 선택도 스크럽도 기준선은 똑같이 **기간 시작**이다(차트가 그 축으로 정규화돼 있다).
따라서 앞말은 양쪽 모두 `기간 시작 대비` 로 같고, `PerformanceHeadline` 은 이름만 넓힌다.

- `scrubbedDate` → `focusedDate`
- `isScrubbing` → `isFocused`

`PerformanceHeadlineView.caption` 의 `"2026년 8월 3일 · 기간 시작 대비"` 는 그대로 맞는
문장이 된다. 액세서리의 `scrubbedHeadlinePrefix` 상수도 값은 그대로 두고 이름만 맞춘다.

## 4. 캘린더 카드

### 4.1 선택 표시

`CalendarHeatmap` 에 `selectedDate: Date?` 를 추가한다.

- 선택 셀: 44pt 프레임 **바깥선**에 `brand` 2pt `strokeBorder`
- 채움 사각형은 **모든 셀에서 항상 2pt 인셋**해 그린다

인셋을 선택 셀에만 적용하면 고른 칸만 작아져 격자가 들쭉날쭉해진다. 전부 인셋하면 채움
크기가 선택 여부와 무관하게 일정하고, 선택 링이 들어올 자리도 늘 비어 있다. 히트 영역은
44pt 그대로 유지한다(`.contentShape(.rect)` 는 프레임 기준).

손실 셀의 `loss` 1pt 스트로크는 인셋된 채움 사각형에 그대로 남는다 — 선택 중에도 "채움 vs
채움+테두리" 라는 색맹 대응 부호가 살아 있다. 두 테두리는 색(brand/loss)·굵기(2pt/1pt)·
위치(프레임 바깥선/채움 경계)가 모두 달라 겹쳐도 구분된다.

접근성: 선택 셀에 `.isSelected` trait 을 더한다. 라벨 문구는 바꾸지 않는다.

### 4.2 임의의 달로 점프

DesignSystem 에 `MonthPickerGrid` 를 새로 만든다.

```swift
public struct MonthPickerGrid: View {
    public init(
        year: Int,
        selectedMonth: Int?,
        disabledMonths: Set<Int>,
        onSelect: @escaping (Int) -> Void
    )
}
```

- 3열 × 4행, 칸 최소 44pt, 라벨은 `1월`~`12월`
- 선택 월은 `brandTint` 채움 + `brand` 라벨 (세그먼트 선택 칸과 같은 문법)
- 비활성 월은 `textSecondary` 잉크 + `.disabled(true)`

카드 헤더 월 라벨을 누르면 일 격자가 **그 자리에서** 12개월 격자로 뒤집히고, ◀▶ 는 년
이동으로 바뀐다(`◀ 2026년 ▶`). 월을 고르면 다시 일 격자로 접힌다. 시트를 쓰지 않는 이유는
셀 상세를 시트로 하지 않은 이유와 같다 — 이 탭엔 이미 기간·벤치마크 시트가 둘이다.

펼침 여부는 `MonthlyReturnCard` 의 `@State private var isMonthPickerExpanded` 다. 어느 달을
보는지는 재조회를 부르므로 ViewModel 이 갖지만, 격자가 뒤집혔는지는 순수한 뷰 상태다.
전환에는 `.hannunAnimation(.selection, value:)` 을 건다.

**비활성 범위는 미래 달·미래 년만이다.** "기록이 없는 달"까지 막으려면 첫 스냅샷 날짜를
알아야 하고 그건 ALL 구간 조회를 한 번 더 태워야 한다. 들어가 봐야 이미 있는 `이 달에는
기록이 없어요` 가 말해 주므로 그 비용을 쓰지 않는다.

ViewModel 변경:

```swift
/// ◀▶ 와 월 점프가 함께 쓰는 진입점. 선택 해제·로딩 표시·재조회를 한 곳에서 한다.
private func setMonth(_ month: Date) async

func showPreviousMonth() async            // 기존 — setMonth 위로 재작성
func showNextMonth() async                // 기존 — setMonth 위로 재작성
func showMonth(year: Int, month: Int) async   // 신규

var canShowNextMonth: Bool                // 기존
var canShowNextYear: Bool                 // 신규
var disabledMonths: Set<Int>              // 신규 — 표시 중인 년이 올해면 이번 달 이후
```

### 4.3 상세 한 줄

`selectedCell` 이 `viewModel.selectedDate` 로 바뀌는 것 외에 문구·색 규칙은 그대로다.
`selectedReturn` 은 `selectedDate` 를 `startOfDay` 로 정규화해 `calendarState` 에서 찾는다
(기존 로직 그대로).

## 5. 차트 카드 — 단위 세그먼트

### 5.1 배치

차트 카드 맨 윗줄 오른쪽에 2칸 세그먼트 `[일별 | 월별]` 를 둔다. 왼쪽은 기존 벤치마크
범례다. 두 선택지가 동시에 보여 한 번에 고를 수 있고, 범례와 같은 줄을 쓰므로 240pt 로 줄인
플롯 세로를 더 먹지 않는다.

§3.1 의 "세그먼트 2칸 이상 금지" 는 **액세서리 캡슐 안**의 규칙이다. 콘텐츠 영역에는
적용되지 않는다.

### 5.2 컴포넌트 경계

`Modules/DesignSystem/Project.swift` 는 `HannunCore` 만 의존한다 — **DesignSystem 은 Domain 을
모른다.** `TrendGranularity` 는 Domain 타입이므로 단위 세그먼트를 그대로 DesignSystem 에 둘 수
없다.

DesignSystem 에 제네릭 세그먼트를 두고 호출부에서 특수화한다.

```swift
public struct SegmentedPicker<Value: Hashable>: View {
    public init(
        _ values: [Value],
        selection: Binding<Value>,
        label: @escaping (Value) -> String
    )
}
```

시각 문법(`.periodSegment` glass 트랙 · `brandTint` 선택 캡슐 · `pillLabel` · 44pt 최소 높이 ·
AX 사이즈 가로 스크롤 폴백)은 기존 `PeriodSegment` 구현을 그대로 옮긴다. `PeriodSegment` 는
호출부가 없는 예약 컴포넌트이므로 `SegmentedPicker` 위로 재구현해도 회귀 위험이 없고, 두
세그먼트가 서로 다른 두 벌로 갈라지는 것을 막는다.

성과 탭 호출부:

```swift
SegmentedPicker(TrendGranularity.allCases, selection: $viewModel.granularity) { $0.title }
```

`granularity` 는 지금 `private(set)` 이고 변경이 재조회를 부른다. 바인딩은
`selectGranularity(_:)` 를 부르는 계산 바인딩으로 만든다 — `BenchmarkPickerSheet` 가
`isBenchmarkOverlayEnabled` 를 다루는 방식과 같다.

### 5.3 차트 헤더 슬롯

`TrendLineChart` 에 `@ViewBuilder header:` 슬롯을 추가해 범례 줄 오른쪽에 호출부가 원하는
것을 얹게 한다. 차트 컴포넌트가 Domain 개념(단위)을 알 필요가 없어진다.

```swift
TrendLineChart(points:benchmarks:insufficientDataMessage:selection:) {
    SegmentedPicker(...)
}
```

- 헤더 줄은 **범례가 없어도** 슬롯 내용이 있으면 그린다(현재는 `showsLegend` 하나로 결정)
- 데이터 1건 이하로 `insufficientDataNotice` 를 그릴 때도 헤더 줄은 남긴다 — 단위를 바꾸면
  점 개수가 달라질 수 있으므로 그 상태에서야말로 컨트롤이 필요하다
- AX5 에서 범례 + 세그먼트가 한 줄에 안 들어가면 `ViewThatFits` 로 2행(범례 → 세그먼트) 폴백

### 5.4 액세서리에서 제거

`PerformanceAccessory.granularityToggle` 과 그에 딸린 상수·접근성 문구를 지운다.
`toggleGranularity()` 도 호출부가 사라지므로 제거하고 `selectGranularity(_:)` 만 남긴다.

## 6. 액세서리

### 6.1 trailing — 벤치마크 비교 on/off

`PerformanceViewModel` 은 이미 "무엇을 비교할지"(`selectedBenchmark`)와 "겹칠지"
(`isBenchmarkOverlayEnabled`)를 일부러 분리해 두고, 주석에 *"끄는 순간 선택이 사라지면 매번
다시 고르게 된다"* 고 적어 놨다. 그런데 그 on/off 스위치는 시트 **안**에 있어서 껐다 켜려면
매번 시트를 열어야 한다 — 분리해 둔 설계가 화면에서 완성되지 않은 상태다.

`AccessoryControlButton` 의 문서 주석도 자기 용도를 *"통화 전환, 벤치마크 비교 on/off"* 라고
적고 있고, `BottomAccessory.swift:196` 프리뷰는 `S&P500 대비 +1.4%p` leading 을 이미 모킹해
두고 있다. 원래 이 자리로 오려던 컨트롤이다.

| 상태 | `.expanded` 라벨 | `.inline` | `isOn` | `indicatesSelection` | 동작 |
|------|-----------------|-----------|--------|---------------------|------|
| 지수 선택됨 | 지수 이름 (`S&P500`) | `chart.line.uptrend.xyaxis` | `isBenchmarkOverlayEnabled` | `true` | `toggleBenchmarkOverlay()` |
| 지수 미선택 | `비교` | 같은 아이콘 | `false` | `false` | `isBenchmarkPickerPresented = true` |

미선택일 때 비활성으로 두지 않는다. 그 상태에서 사용자가 다음에 할 일은 **정확히 하나**
— 비교할 지수를 고르는 것 — 이고, 비활성 버튼은 그 하나를 막고 툴바를 찾게 만든다.
어포던스 거짓말도 아니다: 라벨(`비교`)과 힌트가 세 경우를 각각 다르게 말한다.

접근성 문구:

| 상태 | label | hint |
|------|-------|------|
| 선택됨 · 겹침 ON | `벤치마크 비교, S&P500` | `두 번 탭하면 차트에서 지웁니다` |
| 선택됨 · 겹침 OFF | `벤치마크 비교, S&P500` | `두 번 탭하면 차트에 겹칩니다` |
| 미선택 | `벤치마크 비교` | `두 번 탭하면 비교할 지수를 고릅니다` |

`indicatesSelection` 이 `true` 인 첫 두 경우에만 `.isSelected` trait 이 붙는다 — 한 대상의
두 상태이므로 §3.1 이 요구하는 조건에 맞는다.

툴바 벤치마크 아이콘은 **그대로 남긴다.** 액세서리가 "켤지"를, 툴바 시트가 "무엇을"을 맡는다.

### 6.2 leading — 4단 교대

단위가 차트로 떠났으므로 `periodSummary`("YTD · 일별")를 지우고 `period.title`("YTD")만
말한다. `.inline` 분기도 같은 문구가 되어 사라진다.

| 우선순위 | 조건 | 문구 |
|---------|------|------|
| 1 | 히어로가 보이는 중 | `YTD` + `chevron.up` |
| 2 | `focusedPoint` 있음 (스크럽 또는 날짜 선택 중) | `기간 시작 대비 +3.1%` |
| 3 | 비교 ON + `benchmarkExcessReturn` 있음 | `S&P500 대비 +1.4%p` |
| 4 | 그 외 | `연초 대비 +8.2%` |

2가 3보다 앞서는 이유는 사용자가 지금 손으로 만지고 있는 값이 그것이기 때문이다.

3번 대역이 없으면 비교를 켜도 화면에서 "몇 %p 이기고 있나"를 선 두 개의 간격으로 눈대중해야
한다. 토글과 짝을 이루는 정보라 함께 넣는다. `benchmarkExcessReturn` 은 이미 구현돼 있으나
지금은 테스트에서만 읽히는 죽은 계산 프로퍼티다.

`alternatingCaption` 의 `ZStack` 겹침 방식(폭을 넓은 쪽에 고정 + 투명도 교대)은 그대로 두고
대역만 늘린다. `.accessibilityValue` 도 같은 우선순위로 계산한다.

## 7. 변경 파일

### 신규

| 파일 | 타깃 |
|------|------|
| `Modules/DesignSystem/Sources/Components/SegmentedPicker.swift` | HannunDesignSystem |
| `Modules/DesignSystem/Sources/Components/MonthPickerGrid.swift` | HannunDesignSystem |

### 수정

| 파일 | 내용 |
|------|------|
| `Modules/DesignSystem/Sources/Components/PeriodSegment.swift` | `SegmentedPicker` 위로 재구현 |
| `Modules/DesignSystem/Sources/Components/CalendarHeatmap.swift` | `selectedDate` 파라미터 · 채움 2pt 인셋 · 선택 링 · `.isSelected` |
| `Modules/DesignSystem/Sources/Components/TrendLineChart.swift` | `header:` 슬롯 · 헤더 표시 조건 · AX 2행 폴백 |
| `Features/Performance/Sources/ViewModels/PerformanceViewModel.swift` | `selectedDate` · `focusedDate` · `focusedPoint` · `chartCursorDate` · `selectDate(_:)` · `setMonth(_:)` · `showMonth(year:month:)` · `canShowNextYear` · `disabledMonths` · `toggleGranularity()` 제거 |
| `Features/Performance/Sources/ViewModels/PerformanceState.swift` | `PerformanceHeadline.scrubbedDate` → `focusedDate`, `isScrubbing` → `isFocused` |
| `Features/Performance/Sources/Components/MonthlyReturnCard.swift` | `selectedCell` 제거 · 월 점프 격자 전환 · 년 이동 헤더 |
| `Features/Performance/Sources/Components/PerformanceAccessory.swift` | 단위 토글 → 비교 토글 · leading 4단 교대 |
| `Features/Performance/Sources/Views/PerformanceContentView.swift` | 차트 헤더에 단위 세그먼트 · 커서 계산 바인딩 |
| `Features/Performance/Sources/Components/PerformanceHeadlineView.swift` | 이름 변경 반영 |
| `Features/Performance/Sources/Previews/PerformancePreviewData.swift` | 날짜 선택·비교 ON 프리뷰 케이스 |

### 문서

`docs/design/2026-07-27-ui-design-spec.md`

- §3.1 탭별 내용 표 — 성과 행의 leading/trailing 교체
- §3.1 `.expanded`/`.inline` 표 — 성과 행 교체
- §3.1 "성과: 벤치마크 칩 4개를 폐기하고…" 단락 — 비교 on/off 가 액세서리로 올라온 것 반영
- §4.3 레이아웃 표 — 차트 카드 헤더에 단위 세그먼트 추가
- §4.3 액세서리 절 — leading 4단·trailing 비교 토글로 재작성
- §4.3 "기간·단위 컨트롤을 인라인에 두려던 결정을 뒤집었다" — **단위만 인라인으로 되돌아온**
  후속 결정과 근거를 덧붙인다 (기간은 6칸이라 캡슐에 못 들어가지만 단위는 2칸이고 차트 축과
  직결된다. 액세서리에 남길 이유가 없어졌고 대신 저빈도라던 비교가 실제로는 껐다 켰다 하는
  조작이라 그 자리를 가져갔다)
- §4.3 월간 수익률 캘린더 규칙 — 선택 표시·월 점프 추가
- §7 컴포넌트 인벤토리 — `SegmentedPicker`/`MonthPickerGrid` 추가, `PeriodSegment` 항목을
  "예약 — `SegmentedPicker` 위 특수화" 로 갱신

## 8. 테스트

`Features/Performance/Tests/PerformanceViewModelTests.swift`

| 케이스 | 확인 |
|--------|------|
| 캘린더 날짜 선택 | `focusedDate` == 선택 날짜, `headline.focusedDate` 가 그 날 값 |
| 스크럽이 선택을 덮는다 | 스크럽 중 `focusedDate` == `scrubbedDate`, 손 떼면 선택으로 복귀 |
| 구간 밖 선택 | `chartCursorDate == nil`, `headline` 은 연초 대비 값 유지 |
| 월별 단위 스냅 | 일별 날짜를 골라도 같은 달 점을 집는다 |
| 월 이동 후 선택 해제 | `showPreviousMonth()` / `showMonth(year:month:)` 후 `selectedDate == nil` |
| 기간·단위 변경 후 선택 유지 | `selectPeriod` / `selectGranularity` 후 `selectedDate` 그대로 |
| 비활성 월 계산 | 올해면 이번 달 이후가 `disabledMonths`, 과거 년이면 빈 집합 |
| `canShowNextYear` | 올해면 `false`, 과거 년이면 `true` |

`Modules/DesignSystem/Tests` — `MonthPickerGrid` 는 격자 배치만 하는 뷰라 순수 함수가 없다.
비활성 월 계산은 ViewModel 쪽 테스트가 덮는다. `CalendarHeatmap` 의 기존 순수 함수 테스트는
선택 표시가 뷰 레이어 변경이라 영향받지 않는다.

## 9. 프리뷰

| 대상 | 케이스 |
|------|--------|
| `CalendarHeatmap` | 선택 있음(수익 셀) · 선택 있음(손실 셀 — 두 테두리 공존 확인) · AX5 |
| `MonthPickerGrid` | 올해(뒷달 비활성) · 과거 년(전부 활성) · AX5 |
| `SegmentedPicker` | 2칸(단위) · 6칸(기간) · AX5 가로 스크롤 |
| `MonthlyReturnCard` | 일 격자 · 12개월 격자 펼침 · 라이트/다크/AX5 |
| `PerformanceAccessory` | 비교 OFF · 비교 ON · 지수 미선택 · 날짜 선택 중 · 축약 |
| `PerformanceContentView` | 비교 ON + 날짜 선택 상태 |

## 10. 위험과 완화

| 위험 | 완화 |
|------|------|
| 선택 링과 손실 스트로크가 겹쳐 지저분해 보인다 | 채움을 전 셀 2pt 인셋해 두 테두리를 물리적으로 분리. 손실 셀 선택 프리뷰로 눈으로 확인 |
| 차트 헤더에 범례 + 세그먼트가 AX5 에서 넘친다 | `ViewThatFits` 2행 폴백 + AX5 프리뷰 |
| 지수 이름이 길어 `.expanded` 액세서리가 좁아진다 | §3.1 규칙대로 leading 이 먼저 양보한다 (`AccessoryCaption.expandable()` 이 이미 그 역할) |
| `PeriodSegment` 재구현이 예약 컴포넌트를 깬다 | 호출부가 없어 회귀 대상이 없다. 프리뷰로 시각 동등성만 확인 |
| 월 점프 격자 전환 중 재조회가 겹친다 | 기존 `calendarRequestID` 세대 토큰이 그대로 막는다 |
