//
//  CalendarHeatmap.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/3/26.
//

import SwiftUI

/// 월간 캘린더 히트맵의 한 칸.
///
/// Domain 의 `DailyReturn` 을 그대로 받지 않는다 — DesignSystem 은 Domain 을 모른다.
/// `ratio` 를 `nil` 로 두면 "기록이 없는 날"이고, `0` 이면 "그날은 변동이 없었다"다.
/// 둘을 같은 값으로 합치면 보유는 하고 있었지만 데이터가 비어 있던 날이 손익 0% 로 보인다.
public struct HeatmapCell: Identifiable, Equatable, Sendable {

    // MARK: - Property

    public let date: Date
    /// `0.012` 이 `+1.2%` 다. `nil` 이면 기록이 없는 날 — `0` 과 구분한다.
    public let ratio: Decimal?

    public var id: Date { date }

    // MARK: - Function

    public init(date: Date, ratio: Decimal?) {
        self.date = date
        self.ratio = ratio
    }
}

/// 월간 7×N 그리드로 일별 수익률을 채우는 히트맵.
///
/// **색맹 대응**: 손익 부호를 색만으로 말하지 않는다. 손실 셀에만 `loss` 1pt 스트로크를
/// 둘러 "채움 vs 채움+테두리" 라는 형태 차이로 부호를 병행 표기한다 — `AccessoryActionButton`
/// 의 "primary 채움 / secondary 스트로크" 어휘와 같은 결이다. 명도는 opacity 단계가 맡는다.
///
/// 채움 opacity 상한을 0.60 으로 잡는 이유는 `textPrimary` 로 적은 일 숫자가 라이트·다크
/// 양쪽에서 계속 읽히게 하기 위해서다 — 그래서 `onGain`/`onLoss` 같은 신규 토큰이 필요 없다.
///
/// **선택 표시**: 고른 셀은 44pt 프레임 바깥선에 `brand` 2pt 링을 두른다. 채움 사각형은
/// 선택 여부와 무관하게 **모든 셀에서 2pt 인셋**해 그린다 — 인셋을 선택 셀에만 걸면 고른
/// 칸의 색면만 작아져 격자가 들쭉날쭉해진다. 손실 셀의 `loss` 1pt 스트로크는 인셋된 채움
/// 경계에 그대로 남아 색맹 대응 부호가 선택 중에도 살아 있고, 두 테두리는 색·굵기·위치가
/// 모두 달라 겹쳐도 구분된다.
public struct CalendarHeatmap: View {

    // MARK: - Property

    private let month: Date
    private let cells: [HeatmapCell]
    private let selectedDate: Date?
    private let calendar: Calendar
    private let onSelect: (HeatmapCell) -> Void

    // MARK: - Body

    public init(
        month: Date,
        cells: [HeatmapCell],
        selectedDate: Date? = nil,
        calendar: Calendar = .current,
        onSelect: @escaping (HeatmapCell) -> Void
    ) {
        self.month = month
        self.cells = cells
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.onSelect = onSelect
    }

    public var body: some View {
        // `ForEach` 는 슬롯마다 클로저를 다시 평가한다 — 한 달 안에서 이 딕셔너리를
        // 매번 새로 만들지 않도록 여기서 한 번만 계산해 넘긴다.
        let cellsByDay = cellsByDay
        let selectedDay = selectedDate.map { calendar.startOfDay(for: $0) }

        VStack(alignment: .leading, spacing: .spacingS) {
            weekdayHeader

            LazyVGrid(columns: Constants.columns, spacing: .spacingXS) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarHeatmapDayCell(
                            day: day,
                            cell: cellsByDay[calendar.startOfDay(for: day)],
                            isSelected: selectedDay == calendar.startOfDay(for: day),
                            calendar: calendar,
                            onSelect: onSelect
                        )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: .spacingXS) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .hannunFont(.caption)
                    .minimumScaleFactor(Constants.gridTextMinimumScaleFactor)
                    .lineLimit(1)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Function

    private var days: [Date?] {
        CalendarHeatmap.gridDays(month: month, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        CalendarHeatmap.rotatedWeekdaySymbols(calendar: calendar)
    }

    private var cellsByDay: [Date: HeatmapCell] {
        CalendarHeatmap.cellsByDay(cells, calendar: calendar)
    }
}

/// 그리드·불투명도 계산은 뷰 상태를 보지 않는 순수 함수라 `body` 밖에 둔다 — 그래야 테스트가
/// `View` 를 끌고 오지 않는다. `public` 이 아니라 `internal` 이다 — 컴포넌트의 대외 계약이
/// 아니라 구현 세부라서 모듈 밖에는 드러내지 않는다.
///
/// `CalendarHeatmap` 이 `View` 를 준수해 타입 전체가 `@MainActor` 로 추론되므로,
/// 액터를 안 타는 순수 계산이라는 사실을 `nonisolated` 로 명시한다 — `DonutChart.category`
/// 와 같은 이유다.
extension CalendarHeatmap {

    /// 월 1일부터 말일까지, 앞뒤로 빈 칸을 채워 7 의 배수로 만든다. `nil` 이 빈 칸이다.
    nonisolated static func gridDays(month: Date, calendar: Calendar) -> [Date?] {
        let days = daysInMonth(month: month, calendar: calendar)
        let leading = leadingBlankCount(month: month, calendar: calendar)
        let filled = leading + days.count
        let trailing = (Constants.daysPerWeek - filled % Constants.daysPerWeek)
            % Constants.daysPerWeek

        var padded: [Date?] = Array(repeating: nil, count: leading)
        padded.append(contentsOf: days)
        padded.append(contentsOf: Array(repeating: nil, count: trailing))
        return padded
    }

    /// 그 달 1일의 요일이 `calendar.firstWeekday` 로부터 몇 칸 밀려 있는지.
    ///
    /// `calendar.component(.weekday, from:)` 은 `firstWeekday` 와 무관하게 항상
    /// 일요일 = 1 인 그레고리력 요일 번호를 돌려준다. 그래서 그리드가 실제로 시작하는
    /// 요일(`firstWeekday`) 과의 차이를 직접 계산해야 한다. `+ daysPerWeek` 는 1일의 요일이
    /// `firstWeekday` 보다 앞서는 되감기 케이스(예: 토요일 시작 달력에서 일요일 1일)에
    /// 음수가 나오는 것을 막는다 — 이 항을 빼면 `gridDays` 의 `Array(repeating:count:)` 가
    /// 음수 count 로 런타임에 트랩한다.
    nonisolated static func leadingBlankCount(month: Date, calendar: Calendar) -> Int {
        guard let firstDayOfMonth = firstDayOfMonth(of: month, calendar: calendar) else {
            return 0
        }
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        return (weekday - calendar.firstWeekday + Constants.daysPerWeek) % Constants.daysPerWeek
    }

    /// `calendar.veryShortWeekdaySymbols` 는 `firstWeekday` 와 무관하게 항상 일요일부터
    /// 시작한다. 그대로 그리드 위에 얹으면 `firstWeekday != 1` 인 로케일에서 헤더 글자가
    /// 실제 열보다 밀려 보인다 — 시작 요일만큼 앞으로 돌린다.
    nonisolated static func rotatedWeekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == Constants.daysPerWeek else { return symbols }

        let offset = (calendar.firstWeekday - 1 + Constants.daysPerWeek) % Constants.daysPerWeek
        return Array(symbols[offset...] + symbols[..<offset])
    }

    /// 채움 불투명도 단계. 경계값은 **다음** 단계에 포함된다 — `magnitude < 0.005` 만 0.20,
    /// 정확히 `0.005` 는 이미 0.40 이다.
    nonisolated static func fillOpacity(ratioMagnitude magnitude: Decimal) -> Double {
        if magnitude < Constants.lowOpacityUpperBound { return Constants.lowOpacity }
        if magnitude < Constants.midOpacityUpperBound { return Constants.midOpacity }
        return Constants.highOpacity
    }

    /// 날짜 매칭용 딕셔너리. 키를 `calendar.startOfDay(for:)` 로 정규화한다 — `HeatmapCell.date`
    /// 는 Domain 값에서 넘어오며 시:분:초가 섞여 있을 수 있다. 원시 `Date` 를 키로 쓰면
    /// 조회 쪽(그리드 날짜, 이미 자정)과 어긋나 셀이 전부 "기록 없음" 으로 빠진다.
    nonisolated static func cellsByDay(
        _ cells: [HeatmapCell],
        calendar: Calendar
    ) -> [Date: HeatmapCell] {
        Dictionary(
            cells.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    nonisolated private static func daysInMonth(month: Date, calendar: Calendar) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDayOfMonth = firstDayOfMonth(of: month, calendar: calendar)
        else { return [] }

        return range.compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 1, to: firstDayOfMonth)
        }
    }

    nonisolated private static func firstDayOfMonth(of month: Date, calendar: Calendar) -> Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month))
    }
}

/// 히트맵 한 칸. 기록이 있는 날만 `Button` 이다 — 기록 없는 날은 `.disabled` 대신 아예
/// 버튼이 아니게 만들어 VoiceOver 가 "버튼" 트레이트를 읽지 않게 한다.
private struct CalendarHeatmapDayCell: View {

    // MARK: - Property

    let day: Date
    let cell: HeatmapCell?
    let isSelected: Bool
    let calendar: Calendar
    let onSelect: (HeatmapCell) -> Void

    // MARK: - Body

    var body: some View {
        content
            .aspectRatio(1, contentMode: .fit)
    }

    /// `.frame`/`.background`/`.contentShape` 를 전부 `label:` **안**에서 적용한다 —
    /// `Button` 바깥에 붙이면 레이아웃 프레임만 44pt 로 키울 뿐, 탭 인식 영역은 여전히
    /// 라벨(숫자 글리프) 크기에 머문다. `AccessoryActionButton.swift:85-91` 과 같은
    /// 위치(label 안)에 적용하되 순서는 그것과 반대로 **프레임을 배경보다 먼저** 둔다 —
    /// 배경이 라벨(숫자) 크기가 아니라 프레임이 넓힌 44pt 정사각형 전체를 채워야 셀이
    /// 색칠된 사각형으로 보인다(캡슐 버튼처럼 텍스트만 한 작은 배경 + 여백이 아니다).
    /// 그래야 시각 사각형과 `.contentShape(.rect)` 히트 사각형이 같은 크기가 된다.
    ///
    /// 접근성 라벨은 각 갈래 안에서 직접 붙인다 — 바깥에서 `.accessibilityElement(children:
    /// .ignore)` 로 한 번 더 감싸면 `Button` 이 원래 스스로 하나의 엘리먼트로 접히면서 갖는
    /// `.isButton` 트레이트와 활성화 액션이 사라진다.
    @ViewBuilder
    private var content: some View {
        if let cell, let ratio = cell.ratio {
            Button {
                onSelect(cell)
            } label: {
                dayNumberText
                    .foregroundStyle(Color.textPrimary)
                    .frame(minWidth: .minimumTouchTarget, minHeight: .minimumTouchTarget)
                    .background { fill(for: ratio) }
                    .overlay { selectionRing }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            // 버튼이 아니어도 **프레임은 같아야 한다**. 이 갈래가 맨 텍스트면 높이가 글자
            // 높이(약 15pt)로 주저앉는다. 기록이 하나라도 있는 주는 옆 셀이 44pt 로 행을
            // 붙들어 티가 안 나지만, 한 주가 통째로 비면 그 줄만 눌려 격자가 어긋난다
            // (앞뒤 빈 칸은 `Color.clear` 가 정사각형을 유지해 이 문제가 없다).
            dayNumberText
                .foregroundStyle(Color.textSecondary)
                .frame(minWidth: .minimumTouchTarget, minHeight: .minimumTouchTarget)
                .overlay { selectionRing }
                .accessibilityLabel(accessibilityLabel)
        }
    }

    // MARK: - Function

    private var dayNumberText: some View {
        Text("\(dayNumber)")
            .hannunFont(.caption, tabularFigures: true)
            .minimumScaleFactor(Constants.gridTextMinimumScaleFactor)
            .lineLimit(1)
    }

    private var dayNumber: Int {
        calendar.component(.day, from: day)
    }

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: .radiusS)
    }

    /// 채움 색면. 44pt 프레임 안쪽으로 2pt 물러나 선택 링이 들어올 자리를 늘 비워 둔다 —
    /// 선택된 셀만 물러나면 고른 칸의 색면 크기가 달라져 격자가 들쭉날쭉해 보인다.
    private func fill(for ratio: Decimal) -> some View {
        cellShape
            .fill(fillColor(for: ratio).opacity(fillOpacity(for: ratio)))
            .overlay {
                if ratio < 0 {
                    lossStroke
                }
            }
            .padding(Constants.fillInset)
    }

    /// 인셋 스트로크. `stroke` 대신 `strokeBorder` 를 쓴다 — `stroke` 는 선을 경로 위에
    /// 걸쳐 그려 절반이 셀 바깥으로 번지고 모서리 반경이 `radiusS` 보다 커 보인다.
    /// 다른 컴포넌트의 테두리도 전부 인셋이다(`AccessoryActionButton.swift:135`,
    /// `FilterChip.swift:186`).
    private var lossStroke: some View {
        cellShape.strokeBorder(Color.loss, lineWidth: Constants.lossStrokeWidth)
    }

    /// 선택 링. 채움 경계가 아니라 **프레임 바깥선**에 그려 손실 스트로크와 위치가 겹치지
    /// 않는다 — 색(brand/loss)·굵기(2pt/1pt)까지 달라 두 테두리가 한 셀에 있어도 읽힌다.
    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            cellShape.strokeBorder(Color.brand, lineWidth: Constants.selectionStrokeWidth)
        }
    }

    private func fillColor(for ratio: Decimal) -> Color {
        if ratio == 0 { return .neutral }
        return ratio > 0 ? .gain : .loss
    }

    private func fillOpacity(for ratio: Decimal) -> Double {
        CalendarHeatmap.fillOpacity(ratioMagnitude: ratio.magnitude)
    }

    /// "8월 3일, 수익률 +1.2%" · "8월 3일, 기록 없음". 색을 언급하지 않는다 — 색맹 사용자에게
    /// 형태(스트로크 유무)로 이미 전달한 정보를 색 이름으로 다시 말하면 오히려 소음이다.
    private var accessibilityLabel: String {
        let dateText = day.formatted(.dateTime.month(.wide).day())
        guard let ratio = cell?.ratio else {
            return dateText + Constants.noRecordSuffix
        }
        return dateText + Constants.recordedSeparator
            + AmountFormatter.compactPercentage(ratio: ratio)
    }
}

fileprivate enum Constants {
    static let daysPerWeek = 7
    static let columns = Array(
        repeating: GridItem(.flexible(), spacing: .spacingXS),
        count: daysPerWeek
    )

    static let lowOpacityUpperBound: Decimal = 0.005
    static let midOpacityUpperBound: Decimal = 0.02
    static let lowOpacity = 0.20
    static let midOpacity = 0.40
    static let highOpacity = 0.60

    static let lossStrokeWidth: CGFloat = 1
    static let selectionStrokeWidth: CGFloat = 2
    /// 채움이 44pt 프레임에서 물러나는 폭. 선택 링 굵기와 같아 링이 채움을 덮지 않는다.
    static let fillInset: CGFloat = 2
    /// AX5 에서 두 자리 일 숫자·요일 심볼이 정사각 셀·열 폭을 넘어서면 잘리는 대신 줄어든다.
    static let gridTextMinimumScaleFactor: CGFloat = 0.5

    static let recordedSeparator = ", 수익률 "
    static let noRecordSuffix = ", 기록 없음"
}

#if DEBUG
private struct CalendarHeatmapPreview: View {

    // MARK: - Property

    private let month = CalendarHeatmapPreview.date(year: 2026, month: 8, day: 1)
    private let cells: [HeatmapCell]
    private let selectedDate: Date?

    init(selectedDay: Int? = nil) {
        let calendar = Calendar.current
        // 수익·손실·0%·기록 없음이 모두 들어간 표본. 8월은 31일까지라 다섯째 주까지 채운다.
        let ratiosByDay: [Int: Decimal?] = [
            1: 0.001, 2: 0.004, 3: 0.006, 4: 0.019, 5: 0.021,
            6: 0, 7: -0.002, 8: -0.006, 9: -0.021, 10: nil,
            11: 0.008, 12: -0.011, 13: nil, 14: 0.03, 15: -0.03,
        ]
        // 클로저 안에서 `self.month` 를 바로 캡처하면 "초기화 전 캡처" 컴파일 에러가 난다.
        let anchorMonth = month
        cells = ratiosByDay.compactMap { day, ratio in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: anchorMonth)
            else { return nil }
            return HeatmapCell(date: date, ratio: ratio)
        }
        selectedDate = selectedDay.flatMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: anchorMonth)
        }
    }

    // MARK: - Body

    var body: some View {
        CalendarHeatmap(month: month, cells: cells, selectedDate: selectedDate) { _ in }
            .padding(.spacingL)
            .background(Color.surfacePrimary, in: .hannunContainer())
            .padding(.spacingL)
            .frame(maxWidth: .infinity)
            .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private static func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

#Preview("캘린더 히트맵 · 라이트") {
    CalendarHeatmapPreview()
        .preferredColorScheme(.light)
}

#Preview("캘린더 히트맵 · 다크") {
    CalendarHeatmapPreview()
        .preferredColorScheme(.dark)
}

/// 선택 링이 채움을 덮지 않고 격자 정렬도 흔들지 않는지 — 5일은 채움이 가장 진한 수익 셀이다.
#Preview("캘린더 히트맵 · 수익 셀 선택") {
    CalendarHeatmapPreview(selectedDay: 5)
}

/// 두 테두리가 한 셀에 공존하는 경우. 바깥선 `brand` 2pt 와 채움 경계 `loss` 1pt 가
/// 서로를 먹지 않는지 이 케이스로 본다.
#Preview("캘린더 히트맵 · 손실 셀 선택") {
    CalendarHeatmapPreview(selectedDay: 15)
}

/// 요일 헤더와 일 숫자가 AX5 에서도 7열 그리드를 무너뜨리지 않는지 확인한다.
#Preview("캘린더 히트맵 · AX5") {
    CalendarHeatmapPreview(selectedDay: 15)
        .dynamicTypeSize(.accessibility5)
}
#endif
