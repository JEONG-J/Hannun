//
//  MonthlyReturnCard.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/4/26.
//

import Foundation
import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 차트 카드 아래에 놓이는 월간 수익률 캘린더 (PM-4, 디자인 문서 ④).
///
/// 별도 화면이 아니라 인라인 카드다 — 차트가 "얼마나 올랐나"를 말하고 이 카드가 "어떤 날에
/// 올랐나"를 말한다. 둘을 다른 화면으로 나누면 같은 질문을 두 번 이동해야 답할 수 있다.
///
/// 카드 문법은 `PerformanceContentView.chartCard` 를 그대로 따른다 — `.padding(.spacingL)` +
/// `.hannunGlass(.contentSurface, in: .hannunContainer())`.
///
/// 값이 아니라 ViewModel 을 받는다. 월 이동이 곧 재조회라 카드가 상태를 직접 읽어야 한다.
struct MonthlyReturnCard: View {

    // MARK: - Property

    /// `CalendarHeatmap` 과 **같은** 달력을 써야 한다. 셀 매칭이 `startOfDay` 기준이라
    /// 카드와 컴포넌트가 서로 다른 시간대를 쓰면 상세 한 줄이 엉뚱한 날을 집는다.
    @Environment(\.calendar) private var calendar

    /// 지금 카드가 무엇을 고르는 단계인지. 어느 달을 보는지는 재조회를 부르므로 ViewModel
    /// 이 갖지만, 격자가 어디까지 펼쳐졌는지는 화면을 떠나면 잊어도 그만인 순수한 뷰 상태다.
    @State private var stage: PickerStage = .days

    /// 년 격자가 보고 있는 12년 페이지. 0 이 올해로 끝나는 가장 최신 페이지고, 과거로 갈수록
    /// 늘어난다.
    @State private var yearPageOffset = 0

    private let viewModel: PerformanceViewModel

    /// 단계가 바뀔 때마다 부른다. 카드 높이가 단계마다 달라지는데 이 카드는 페이지 맨 아래에
    /// 있어서, 스크롤을 따라 내리는 일은 스크롤을 쥔 부모만 할 수 있다.
    private let onStageChange: () -> Void

    // MARK: - Body

    init(viewModel: PerformanceViewModel, onStageChange: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onStageChange = onStageChange
    }

    #if DEBUG
    /// 프리뷰 전용. 펼쳐진 격자는 탭으로만 도달하는 상태라 정적 프리뷰가 볼 방법이 없다.
    fileprivate init(viewModel: PerformanceViewModel, stage: PickerStage) {
        self.viewModel = viewModel
        onStageChange = {}
        _stage = State(initialValue: stage)
    }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            header

            content

            if let dailyReturn = selectedReturn {
                detailRow(for: dailyReturn)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingL)
        .hannunGlass(.contentSurface, in: .hannunContainer())
        .hannunAnimation(.selection, value: viewModel.selectedDate)
        .hannunAnimation(.selection, value: stage)
        .onChange(of: stage) { _, _ in onStageChange() }
    }

    /// 화살표가 무엇을 옮기는지는 단계가 정한다 — 열두 달이 한눈에 있는데 그 위에서 월
    /// 화살표를 남겨 두면 같은 일을 두 손잡이가 하게 된다.
    private var header: some View {
        HStack(spacing: .spacingS) {
            arrowButton(
                systemImageName: Constants.previousSymbolName,
                accessibilityLabel: stage.previousAccessibilityLabel,
                isEnabled: true
            ) {
                await showPrevious()
            }

            Spacer(minLength: 0)

            titleButton

            Spacer(minLength: 0)

            arrowButton(
                systemImageName: Constants.nextSymbolName,
                accessibilityLabel: stage.nextAccessibilityLabel,
                isEnabled: canShowNext
            ) {
                await showNext()
            }
        }
    }

    /// 타이틀 자체가 격자를 한 단계 넓히는 손잡이다. 셰브런을 붙여 눌린다고 말한다 — 시트를
    /// 여는 액세서리 캡션과 달리 여기서는 위아래로 뒤집히므로 방향이 그대로 의미가 된다.
    /// 마지막 단계에서만 위를 향하는 이유는 거기서 한 번에 달력까지 접히기 때문이다.
    private var titleButton: some View {
        Button {
            stage = stage.next
        } label: {
            HStack(spacing: .spacingXS) {
                Text(title)
                    .hannunFont(.subtext, tabularFigures: true)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.titleMinimumScaleFactor)

                Image(systemName: stage == .years
                    ? Constants.collapseSymbolName
                    : Constants.expandSymbolName)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(minHeight: .minimumTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(stage.titleAccessibilityHint)
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .days:
            calendarContent
        case .months:
            MonthPickerGrid(
                year: viewModel.displayedYear,
                selectedMonth: viewModel.displayedMonth,
                disabledMonths: viewModel.disabledMonths
            ) { selectMonth($0) }
        case .years:
            // 비활성 칸을 주지 않는다 — 최신 페이지가 올해로 끝나 미래 연도가 격자에 아예
            // 없다. `disabledMonths` 와 달리 막을 대상 자체가 생기지 않는다.
            PickerGrid(
                Array(yearPage),
                selection: viewModel.displayedYear,
                label: { String($0) },
                accessibilityLabel: { Constants.accessibilityLabel(ofYear: $0) },
                onSelect: { selectYear($0) }
            )
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch viewModel.calendarState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacingXXL)
        case let .loaded(dailyReturns) where dailyReturns.isEmpty:
            // `EmptyStateView` 를 쓰지 않는다 — 카드 안 한 섹션이라 삽화 + CTA 는 과하고,
            // 화면 전체가 비었다는 오해를 준다.
            Text(Constants.emptyMessage)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacingXXL)
        case let .loaded(dailyReturns):
            CalendarHeatmap(
                month: viewModel.calendarMonth,
                cells: dailyReturns.map { HeatmapCell(date: $0.date, ratio: $0.rate) },
                selectedDate: viewModel.selectedDate,
                calendar: calendar
            ) { viewModel.selectDate($0.date) }
        case let .failed(error):
            EmptyStateView(
                systemImageName: Constants.failureSymbolName,
                title: Constants.failureTitle,
                message: error.userMessage,
                actionTitle: Constants.retryTitle
            ) {
                Task { await viewModel.loadCalendar() }
            }
        }
    }

    // MARK: - Function

    private func arrowButton(
        systemImageName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImageName)
                .hannunFont(.subtext)
                // `.buttonStyle(.plain)` 은 비활성 라벨을 흐리게 만들지 않는다 — 잉크를
                // 직접 낮춰야 못 누르는 상태가 눈에 보인다.
                .foregroundStyle(isEnabled ? Color.brand : Color.textSecondary)
                .frame(minWidth: .minimumTouchTarget, minHeight: .minimumTouchTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func showPrevious() async {
        switch stage {
        case .days:
            await viewModel.showPreviousMonth()
        case .months:
            await viewModel.showPreviousYear()
        case .years:
            yearPageOffset += 1
        }
    }

    private func showNext() async {
        switch stage {
        case .days:
            await viewModel.showNextMonth()
        case .months:
            await viewModel.showNextYear()
        case .years:
            yearPageOffset -= 1
        }
    }

    /// 고른 달로 접으면서 옮긴다. 년은 **접기 전** 값을 잡아 둔다 — 재조회가 끝나기 전에
    /// 격자가 사라지므로 `viewModel` 을 다시 읽을 시점이 애매해진다.
    private func selectMonth(_ month: Int) {
        let year = viewModel.displayedYear
        stage = .days
        Task { await viewModel.showMonth(year: year, month: month) }
    }

    /// 해를 고르면 접지 않고 월 격자로 한 칸만 돌아온다 — 그 해의 어느 달을 볼지가 다음
    /// 걸음이기 때문이다. 페이지는 최신으로 되돌린다: 다시 펼쳤을 때 몇 페이지 전에 두고 온
    /// 자리가 아니라 고른 해가 보이는 자리에서 시작해야 한다.
    private func selectYear(_ year: Int) {
        stage = .months
        yearPageOffset = 0
        Task { await viewModel.showYear(year) }
    }

    /// "8월 3일 · +1.2% · +₩142,000".
    ///
    /// 한 `Text` 한 문단으로 만든다 — `HStack` 으로 쪼개면 AX5 에서 조각들이 각자 줄바꿈해
    /// 세 덩어리로 흩어진다. 색이 구간마다 다르므로 `AttributedString` 으로 잇는다
    /// (`Text + Text` 는 iOS 26 에서 deprecated).
    private func detailRow(for dailyReturn: DailyReturn) -> some View {
        Text(detailText(for: dailyReturn))
            .hannunFont(.subtext, tabularFigures: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailText(for dailyReturn: DailyReturn) -> AttributedString {
        let color = changeColor(for: dailyReturn.rate)

        var date = AttributedString(dailyReturn.date.formatted(.dateTime.month(.wide).day()))
        date.foregroundColor = .textPrimary

        var separator = AttributedString(Constants.detailSeparator)
        separator.foregroundColor = .textSecondary

        var rate = AttributedString(AmountFormatter.compactPercentage(ratio: dailyReturn.rate))
        rate.foregroundColor = color

        var gain = AttributedString(
            AmountFormatter.compact(dailyReturn.gain, showsPositiveSign: true)
        )
        gain.foregroundColor = color

        return date + separator + rate + separator + gain
    }

    /// `CalendarHeatmap` 의 채움 색과 같은 규칙이다 — 셀은 회색인데 아래 한 줄만 초록이면
    /// 같은 값을 두 가지로 말하는 셈이 된다.
    private func changeColor(for rate: Decimal) -> Color {
        if rate == 0 { return .neutral }
        return rate > 0 ? .gain : .loss
    }

    /// 다음 걸음으로 넘어갈 수 있는지. 아직 오지 않은 시점에는 칠할 기록이 없고, 년 격자는
    /// 최신 페이지가 올해로 끝나므로 그 페이지에서 ▶ 가 갈 곳이 없다.
    private var canShowNext: Bool {
        switch stage {
        case .days: viewModel.canShowNextMonth
        case .months: viewModel.canShowNextYear
        case .years: yearPageOffset > 0
        }
    }

    /// 년 격자 한 페이지. 월 격자와 같은 3열 4행이라 두 단계를 오가도 카드 높이가 널뛰지 않는다.
    ///
    /// 과거 하한은 두지 않는다 — 첫 기록이 언제인지 모르는 상태에서 끊으면 임의의 벽이 된다.
    private var yearPage: ClosedRange<Int> {
        let lastYear = viewModel.currentYear - Constants.yearsPerPage * yearPageOffset
        return (lastYear - Constants.yearsPerPage + 1)...lastYear
    }

    /// 고른 날의 파생값. 양쪽 모두 `startOfDay` 로 맞춘다 — 스냅샷 `recordedOn` 에는 시:분이
    /// 섞여 있어서 원시 `Date` 로 비교하면 늘 어긋난다.
    ///
    /// 격자가 펼쳐진 동안에는 상세 줄을 접는다. 격자에 없는 날을 가리키는 한 줄이 달·년 칸
    /// 아래 남으면 그 칸의 값처럼 읽힌다.
    private var selectedReturn: DailyReturn? {
        guard
            stage == .days,
            let selectedDate = viewModel.selectedDate,
            let dailyReturns = viewModel.calendarState.value
        else { return nil }

        let selectedDay = calendar.startOfDay(for: selectedDate)
        return dailyReturns.first { calendar.startOfDay(for: $0.date) == selectedDay }
    }

    /// 단계가 고르는 대상만 말한다 — 달을 고르는 자리에서 달 이름까지 붙이면 그 값이 이미
    /// 정해진 것처럼 읽힌다.
    private var title: String {
        switch stage {
        case .days: viewModel.calendarMonth.formatted(.dateTime.year().month(.wide))
        case .months: viewModel.calendarMonth.formatted(.dateTime.year())
        case .years: Constants.title(ofYearPage: yearPage)
        }
    }
}

/// 카드가 무엇을 고르는 단계인지. 일 → 월 → 년 순으로 한 칸씩 넓어지고, 년에서는 두 칸을
/// 되짚지 않고 한 번에 달력으로 접힌다 — 해를 골랐다면 이미 월 격자를 지나온 뒤다.
fileprivate enum PickerStage {
    case days
    case months
    case years

    var next: PickerStage {
        switch self {
        case .days: .months
        case .months: .years
        case .years: .days
        }
    }

    var previousAccessibilityLabel: String {
        switch self {
        case .days: Constants.previousMonthAccessibilityLabel
        case .months: Constants.previousYearAccessibilityLabel
        case .years: Constants.previousYearPageAccessibilityLabel
        }
    }

    var nextAccessibilityLabel: String {
        switch self {
        case .days: Constants.nextMonthAccessibilityLabel
        case .months: Constants.nextYearAccessibilityLabel
        case .years: Constants.nextYearPageAccessibilityLabel
        }
    }

    var titleAccessibilityHint: String {
        switch self {
        case .days: Constants.monthPickerAccessibilityHint
        case .months: Constants.yearPickerAccessibilityHint
        case .years: Constants.collapseAccessibilityHint
        }
    }
}

fileprivate enum Constants {
    static let previousSymbolName = "chevron.left"
    static let nextSymbolName = "chevron.right"
    static let expandSymbolName = "chevron.down"
    static let collapseSymbolName = "chevron.up"
    static let previousMonthAccessibilityLabel = "이전 달"
    static let nextMonthAccessibilityLabel = "다음 달"
    static let previousYearAccessibilityLabel = "이전 해"
    static let nextYearAccessibilityLabel = "다음 해"
    static let previousYearPageAccessibilityLabel = "이전 연도 묶음"
    static let nextYearPageAccessibilityLabel = "다음 연도 묶음"
    static let monthPickerAccessibilityHint = "두 번 탭하면 다른 달을 고를 수 있어요"
    static let yearPickerAccessibilityHint = "두 번 탭하면 다른 해를 고를 수 있어요"
    static let collapseAccessibilityHint = "두 번 탭하면 달력으로 돌아갑니다"
    static let emptyMessage = "이 달에는 기록이 없어요"
    static let failureSymbolName = "exclamationmark.triangle"
    static let failureTitle = "캘린더를 불러오지 못했어요"
    static let retryTitle = "다시 시도"
    static let detailSeparator = " · "
    /// 월 격자와 같은 3열 4행.
    static let yearsPerPage = 12
    /// AX5 에서 "2026년 8월"·"2015 – 2026" 이 화살표 둘 사이 폭을 넘어서면 잘리는 대신 줄어든다.
    static let titleMinimumScaleFactor: CGFloat = 0.7

    static func accessibilityLabel(ofYear year: Int) -> String {
        "\(year)년"
    }

    static func title(ofYearPage page: ClosedRange<Int>) -> String {
        "\(page.lowerBound) – \(page.upperBound)"
    }
}

#if DEBUG
private struct MonthlyReturnCardPreview: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel

    private let stage: PickerStage

    // MARK: - Body

    @MainActor
    fileprivate init(viewModel: PerformanceViewModel, stage: PickerStage = .days) {
        _viewModel = State(initialValue: viewModel)
        self.stage = stage
    }

    var body: some View {
        MonthlyReturnCard(viewModel: viewModel, stage: stage)
            .padding(.spacingL)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.backgroundPrimary)
            .task { await viewModel.loadCalendar() }
    }
}

#Preview("월간 수익률 캘린더 · 라이트") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar)
        .preferredColorScheme(.light)
}

#Preview("월간 수익률 캘린더 · 다크") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar)
        .preferredColorScheme(.dark)
}

/// 헤더 한 줄(화살표 · 월 라벨)과 7열 격자가 AX5 에서도 무너지지 않는지 본다.
#Preview("월간 수익률 캘린더 · AX5") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar)
        .dynamicTypeSize(.accessibility5)
}

/// 날짜를 고른 상태 — 격자의 선택 링과 아래 상세 한 줄이 같은 날을 가리키는지 본다.
#Preview("월간 수익률 캘린더 · 날짜 선택") {
    MonthlyReturnCardPreview(viewModel: .previewWithSelectedDate)
}

/// 12개월 격자로 뒤집힌 상태. 카드 높이가 일 격자와 크게 어긋나지 않는지 함께 본다.
#Preview("월간 수익률 캘린더 · 월 선택 격자") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar, stage: .months)
}

#Preview("월간 수익률 캘린더 · 월 선택 격자 AX5") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar, stage: .months)
        .dynamicTypeSize(.accessibility5)
}

/// 12년 격자. 월 격자와 같은 3열 4행이라 두 단계 사이에서 높이가 튀지 않아야 한다.
#Preview("월간 수익률 캘린더 · 년 선택 격자") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar, stage: .years)
        .preferredColorScheme(.light)
}

#Preview("월간 수익률 캘린더 · 년 선택 격자 AX5") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar, stage: .years)
        .dynamicTypeSize(.accessibility5)
}

#Preview("월간 수익률 캘린더 · 빈 달") {
    MonthlyReturnCardPreview(viewModel: .previewWithoutRecords)
}

#Preview("월간 수익률 캘린더 · 실패") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendarFailure)
}
#endif
