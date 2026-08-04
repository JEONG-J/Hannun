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

    /// 탭한 셀. 시트가 아니라 카드 안 한 줄로 펼친다 — 이 탭에는 이미 기간·벤치마크 시트가
    /// 둘이라 셋째를 띄우면 "눌렀더니 또 시트" 가 된다.
    @State private var selectedCell: HeatmapCell?

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

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
        .hannunAnimation(.selection, value: selectedCell)
        // 달을 옮기면 지난 달 날짜를 가리키던 한 줄이 남는다 — 선택을 함께 푼다.
        .onChange(of: viewModel.calendarMonth) { selectedCell = nil }
    }

    private var header: some View {
        HStack(spacing: .spacingS) {
            monthButton(
                systemImageName: Constants.previousMonthSymbolName,
                accessibilityLabel: Constants.previousMonthAccessibilityLabel,
                isEnabled: true
            ) {
                await viewModel.showPreviousMonth()
            }

            Spacer(minLength: 0)

            Text(monthTitle)
                .hannunFont(.subtext, tabularFigures: true)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(Constants.monthTitleMinimumScaleFactor)

            Spacer(minLength: 0)

            monthButton(
                systemImageName: Constants.nextMonthSymbolName,
                accessibilityLabel: Constants.nextMonthAccessibilityLabel,
                isEnabled: viewModel.canShowNextMonth
            ) {
                await viewModel.showNextMonth()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
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
                calendar: calendar,
                onSelect: select
            )
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

    private func monthButton(
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

    /// 같은 셀을 다시 누르면 접힌다 — 펼친 줄을 닫을 다른 손잡이를 만들지 않기 위해서다.
    private func select(_ cell: HeatmapCell) {
        selectedCell = selectedCell?.date == cell.date ? nil : cell
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

    /// 셀은 금액을 들고 있지 않다(`HeatmapCell` 은 비율만 안다) — 날짜로 파생값을 되찾는다.
    /// 양쪽 모두 `startOfDay` 로 맞춘다. 스냅샷 `recordedOn` 에는 시:분이 섞여 있어서
    /// 원시 `Date` 로 비교하면 늘 어긋난다.
    private var selectedReturn: DailyReturn? {
        guard
            let selectedCell,
            let dailyReturns = viewModel.calendarState.value
        else { return nil }

        let selectedDay = calendar.startOfDay(for: selectedCell.date)
        return dailyReturns.first { calendar.startOfDay(for: $0.date) == selectedDay }
    }

    private var monthTitle: String {
        viewModel.calendarMonth.formatted(.dateTime.year().month(.wide))
    }
}

fileprivate enum Constants {
    static let previousMonthSymbolName = "chevron.left"
    static let nextMonthSymbolName = "chevron.right"
    static let previousMonthAccessibilityLabel = "이전 달"
    static let nextMonthAccessibilityLabel = "다음 달"
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

    // MARK: - Body

    @MainActor
    init(viewModel: PerformanceViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        MonthlyReturnCard(viewModel: viewModel)
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

#Preview("월간 수익률 캘린더 · 빈 달") {
    MonthlyReturnCardPreview(viewModel: .previewWithoutRecords)
}

#Preview("월간 수익률 캘린더 · 실패") {
    MonthlyReturnCardPreview(viewModel: .previewWithCalendarFailure)
}
#endif
