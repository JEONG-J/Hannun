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

    /// 일 격자가 12개월 격자로 뒤집혀 있는지. 어느 달을 보는지는 재조회를 부르므로 ViewModel
    /// 이 갖지만, 격자가 뒤집혔는지는 화면을 떠나면 잊어도 그만인 순수한 뷰 상태다.
    @State private var isMonthPickerExpanded = false

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    #if DEBUG
    /// 프리뷰 전용. 뒤집힌 격자는 탭으로만 도달하는 상태라 정적 프리뷰가 볼 방법이 없다.
    init(viewModel: PerformanceViewModel, isMonthPickerExpanded: Bool) {
        self.viewModel = viewModel
        _isMonthPickerExpanded = State(initialValue: isMonthPickerExpanded)
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
        .hannunAnimation(.selection, value: isMonthPickerExpanded)
    }

    /// 화살표는 격자가 뒤집힌 동안 **년 이동**이 된다 — 12개월이 한눈에 있는데 그 위에서
    /// 월 화살표를 남겨 두면 같은 일을 두 손잡이가 하게 된다.
    private var header: some View {
        HStack(spacing: .spacingS) {
            arrowButton(
                systemImageName: Constants.previousSymbolName,
                accessibilityLabel: isMonthPickerExpanded
                    ? Constants.previousYearAccessibilityLabel
                    : Constants.previousMonthAccessibilityLabel,
                isEnabled: true
            ) {
                if isMonthPickerExpanded {
                    await viewModel.showPreviousYear()
                } else {
                    await viewModel.showPreviousMonth()
                }
            }

            Spacer(minLength: 0)

            titleButton

            Spacer(minLength: 0)

            arrowButton(
                systemImageName: Constants.nextSymbolName,
                accessibilityLabel: isMonthPickerExpanded
                    ? Constants.nextYearAccessibilityLabel
                    : Constants.nextMonthAccessibilityLabel,
                isEnabled: isMonthPickerExpanded
                    ? viewModel.canShowNextYear
                    : viewModel.canShowNextMonth
            ) {
                if isMonthPickerExpanded {
                    await viewModel.showNextYear()
                } else {
                    await viewModel.showNextMonth()
                }
            }
        }
    }

    /// 월 라벨 자체가 격자를 뒤집는 손잡이다. 셰브런을 붙여 눌린다고 말한다 — 시트를 여는
    /// 액세서리 캡션과 달리 여기서는 위아래로 뒤집히므로 방향이 그대로 의미가 된다.
    private var titleButton: some View {
        Button {
            isMonthPickerExpanded.toggle()
        } label: {
            HStack(spacing: .spacingXS) {
                Text(title)
                    .hannunFont(.subtext, tabularFigures: true)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.monthTitleMinimumScaleFactor)

                Image(systemName: isMonthPickerExpanded
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
        .accessibilityHint(isMonthPickerExpanded
            ? Constants.collapseAccessibilityHint
            : Constants.expandAccessibilityHint)
    }

    @ViewBuilder
    private var content: some View {
        if isMonthPickerExpanded {
            MonthPickerGrid(
                year: viewModel.displayedYear,
                selectedMonth: viewModel.displayedMonth,
                disabledMonths: viewModel.disabledMonths
            ) { selectMonth($0) }
        } else {
            calendarContent
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

    /// 고른 달로 접으면서 옮긴다. 년은 **접기 전** 값을 잡아 둔다 — 재조회가 끝나기 전에
    /// 격자가 사라지므로 `viewModel` 을 다시 읽을 시점이 애매해진다.
    private func selectMonth(_ month: Int) {
        let year = viewModel.displayedYear
        isMonthPickerExpanded = false
        Task { await viewModel.showMonth(year: year, month: month) }
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

    /// 고른 날의 파생값. 양쪽 모두 `startOfDay` 로 맞춘다 — 스냅샷 `recordedOn` 에는 시:분이
    /// 섞여 있어서 원시 `Date` 로 비교하면 늘 어긋난다.
    ///
    /// 월 격자가 펼쳐진 동안에는 상세 줄을 접는다. 격자에 없는 날을 가리키는 한 줄이 12개월
    /// 아래 남으면 그 달의 값처럼 읽힌다.
    private var selectedReturn: DailyReturn? {
        guard
            !isMonthPickerExpanded,
            let selectedDate = viewModel.selectedDate,
            let dailyReturns = viewModel.calendarState.value
        else { return nil }

        let selectedDay = calendar.startOfDay(for: selectedDate)
        return dailyReturns.first { calendar.startOfDay(for: $0.date) == selectedDay }
    }

    /// 격자가 뒤집혀 있으면 년만 말한다 — 그 아래에서 고를 대상이 달이기 때문이다.
    private var title: String {
        guard !isMonthPickerExpanded else {
            return viewModel.calendarMonth.formatted(.dateTime.year())
        }
        return viewModel.calendarMonth.formatted(.dateTime.year().month(.wide))
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
    static let expandAccessibilityHint = "두 번 탭하면 다른 달을 고를 수 있어요"
    static let collapseAccessibilityHint = "두 번 탭하면 달력으로 돌아갑니다"
    static let emptyMessage = "이 달에는 기록이 없어요"
    static let failureSymbolName = "exclamationmark.triangle"
    static let failureTitle = "캘린더를 불러오지 못했어요"
    static let retryTitle = "다시 시도"
    static let detailSeparator = " · "
    /// AX5 에서 "2026년 8월" 이 화살표 둘 사이 폭을 넘어서면 잘리는 대신 줄어든다.
    static let monthTitleMinimumScaleFactor: CGFloat = 0.7
}

#if DEBUG
private struct MonthlyReturnCardPreview: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel

    private let isMonthPickerExpanded: Bool

    // MARK: - Body

    @MainActor
    init(viewModel: PerformanceViewModel, isMonthPickerExpanded: Bool = false) {
        _viewModel = State(initialValue: viewModel)
        self.isMonthPickerExpanded = isMonthPickerExpanded
    }

    var body: some View {
        MonthlyReturnCard(viewModel: viewModel, isMonthPickerExpanded: isMonthPickerExpanded)
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
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar, isMonthPickerExpanded: true)
}

#Preview("월간 수익률 캘린더 · 월 선택 격자 AX5") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendar, isMonthPickerExpanded: true)
        .dynamicTypeSize(.accessibility5)
}

#Preview("월간 수익률 캘린더 · 빈 달") {
    MonthlyReturnCardPreview(viewModel: .previewWithoutRecords)
}

#Preview("월간 수익률 캘린더 · 실패") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendarFailure)
}
#endif
