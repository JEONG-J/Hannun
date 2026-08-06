//
//  PeriodRangeSheet.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/6/26.
//

import Foundation
import HannunDesignSystem
import SwiftUI

/// 차트 기간을 특정 개월 범위로 직접 고르는 시트 (PM-3).
///
/// 기간 메뉴의 프리셋 여섯 개는 전부 "지금까지" 라 지난 어느 구간만 떼어 볼 수 없다. 그
/// 자리를 이 시트가 채운다 — 시작·종료 두 끝점을 한 격자로 번갈아 고른다.
///
/// 시트가 고르는 값은 시작할 때 잡은 뒤 `적용` 을 누를 때까지 **여기서만** 산다. ViewModel 에
/// 올리면 끝점을 옮길 때마다 재조회가 따라와 시트를 닫기도 전에 차트가 여러 번 다시 그려진다.
/// 그래서 내려가는 것만으로 취소가 되고, 별도 취소 버튼을 두지 않는다
/// (`BenchmarkPickerSheet` 도 같은 이유로 닫는 손잡이가 하나다).
struct PeriodRangeSheet: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    /// 지금 고치고 있는 끝점.
    @State private var editingEndpoint: Endpoint = .start

    @State private var startMonth: YearMonth
    @State private var endMonth: YearMonth

    /// 격자가 펼쳐 놓은 해. 고른 끝점의 해와 **분리한다** — 화살표로 훑는 동안 값이 따라
    /// 움직이면 지나온 해가 전부 한 번씩 선택된 셈이 된다. 달을 눌러야 값이 바뀐다.
    @State private var displayedYear: Int

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    @MainActor
    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel

        let range = Self.initialRange(of: viewModel)
        _startMonth = State(initialValue: range.start)
        _endMonth = State(initialValue: range.end)
        _displayedYear = State(initialValue: range.start.year)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacingL) {
                    SegmentedPicker(Endpoint.allCases, selection: $editingEndpoint) { $0.title }
                        .frame(maxWidth: .infinity)

                    yearRow

                    MonthPickerGrid(
                        year: displayedYear,
                        selectedMonth: selectedMonth,
                        disabledMonths: viewModel.disabledMonths(inYear: displayedYear)
                    ) { selectMonth($0) }

                    summary

                    applyButton
                }
                .padding(.spacingL)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .hannunAnimation(.selection, value: displayedYear)
        // AX 사이즈에서는 격자만으로 medium 을 채우므로 큰 detent 로 올릴 길을 함께 연다.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: editingEndpoint) { _, endpoint in
            displayedYear = yearMonth(of: endpoint).year
        }
    }

    /// 캘린더 카드의 월 격자 헤더와 같은 문법이다 — 같은 격자를 이동시키는 화살표가 화면마다
    /// 다르게 생기면 안 된다. 과거 하한은 두지 않는다(첫 기록이 언제인지 모른다).
    private var yearRow: some View {
        HStack(spacing: .spacingS) {
            arrowButton(
                systemImageName: Constants.previousSymbolName,
                accessibilityLabel: Constants.previousYearAccessibilityLabel,
                isEnabled: true
            ) {
                displayedYear -= 1
            }

            Spacer(minLength: 0)

            Text(verbatim: String(displayedYear))
                .hannunFont(.subtext, tabularFigures: true)
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: 0)

            arrowButton(
                systemImageName: Constants.nextSymbolName,
                accessibilityLabel: Constants.nextYearAccessibilityLabel,
                isEnabled: displayedYear < viewModel.currentYear
            ) {
                displayedYear += 1
            }
        }
    }

    /// 고른 구간을 한 줄로 되읽어 준다. 격자는 한 번에 한 끝점만 보여 주므로 이 줄이 없으면
    /// 시작을 고치는 동안 종료가 어디였는지 기억해야 한다.
    private var summary: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(Constants.summary(start: startMonth, end: endMonth))
                .hannunFont(.body, tabularFigures: true)
                .foregroundStyle(Color.textPrimary)

            if !isRangeValid {
                Text(Constants.invalidRangeMessage)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.loss)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var applyButton: some View {
        Button(Constants.applyTitle) {
            apply()
        }
        .frame(maxWidth: .infinity, minHeight: .minimumTouchTarget)
        .hannunButtonStyle(.sheetPrimary)
        .tint(Color.brand)
        .disabled(!isRangeValid)
    }

    // MARK: - Function

    private func arrowButton(
        systemImageName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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

    /// 다른 해를 훑는 동안에는 격자에 선택이 없다 — 고른 달은 그 해의 칸이 아니다.
    private var selectedMonth: Int? {
        let editing = yearMonth(of: editingEndpoint)
        return editing.year == displayedYear ? editing.month : nil
    }

    private var isRangeValid: Bool {
        startMonth <= endMonth
    }

    private func yearMonth(of endpoint: Endpoint) -> YearMonth {
        switch endpoint {
        case .start: startMonth
        case .end: endMonth
        }
    }

    private func selectMonth(_ month: Int) {
        let selected = YearMonth(year: displayedYear, month: month)

        switch editingEndpoint {
        case .start: startMonth = selected
        case .end: endMonth = selected
        }
    }

    /// 고른 두 달을 **시작월 1일 00:00 ~ 종료월 말일 23:59:59** 로 펼쳐 넘긴다.
    ///
    /// 상한을 말일 자정이 아니라 하루 끝으로 두는 이유는 저장소가 `recordedOn <= end` 로
    /// 걸러서다 — 자정으로 두면 말일 낮에 찍힌 스냅샷이 구간 밖으로 밀려난다
    /// (`PerformanceViewModel.calendarRange` 와 같은 규칙).
    private func apply() {
        let calendar = Calendar.current

        guard
            isRangeValid,
            let start = startMonth.startDate(calendar: calendar),
            let lastMonth = endMonth.startDate(calendar: calendar),
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: lastMonth),
            let end = calendar.date(byAdding: .second, value: -1, to: nextMonth)
        else { return }

        Task { await viewModel.selectPeriod(.custom(start: start, end: end)) }
        dismiss()
    }

    /// 뜰 때 무엇을 가리키고 있을지. 이미 직접 고른 구간이면 그 값을 그대로 잇고, 프리셋이면
    /// 차트가 **지금 그리고 있는** 첫 점·끝 점의 달을 집는다.
    ///
    /// 구간 계산(`dateRange`)을 쓰지 않는 이유는 `.all` 이다 — 하한이 `distantPast` 라 그
    /// 값을 그대로 열면 격자가 사천 년 전 해에서 시작한다. 그릴 점이 하나도 없을 때만 오늘로
    /// 떨어진다.
    @MainActor
    private static func initialRange(
        of viewModel: PerformanceViewModel
    ) -> (start: YearMonth, end: YearMonth) {
        if case let .custom(start, end) = viewModel.period {
            return (YearMonth(start), YearMonth(end))
        }

        let drawnPoints = viewModel.trendState.value?.portfolio
        return (
            YearMonth(drawnPoints?.first?.date ?? Date()),
            YearMonth(drawnPoints?.last?.date ?? Date())
        )
    }
}

/// 지금 고치고 있는 끝점.
fileprivate enum Endpoint: CaseIterable, Sendable {
    case start
    case end

    var title: String {
        switch self {
        case .start: "시작"
        case .end: "종료"
        }
    }
}

/// 시트가 다루는 값. 시각이 아니라 **년·월 한 칸**이라 격자가 고르는 단위와 그대로 맞는다 —
/// `Date` 로 들고 있으면 같은 달을 가리키는 값이 시:분마다 달라져 선택 비교가 어긋난다.
fileprivate struct YearMonth: Comparable {
    let year: Int
    let month: Int

    var title: String {
        "\(year)년 \(month)월"
    }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(_ date: Date, calendar: Calendar = .current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    func startDate(calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month))
    }
}

fileprivate enum Constants {
    static let title = "기간 직접 선택"
    static let applyTitle = "적용"
    static let previousSymbolName = "chevron.left"
    static let nextSymbolName = "chevron.right"
    static let previousYearAccessibilityLabel = "이전 해"
    static let nextYearAccessibilityLabel = "다음 해"
    static let invalidRangeMessage = "시작이 종료보다 뒤예요. 두 달을 바꿔 골라 주세요."

    static func summary(start: YearMonth, end: YearMonth) -> String {
        "\(start.title) – \(end.title)"
    }
}

#if DEBUG
private struct PeriodRangeSheetPreview: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel = .preview

    // MARK: - Body

    var body: some View {
        PeriodRangeSheet(viewModel: viewModel)
            .task { await viewModel.loadIfNeeded() }
    }
}

#Preview("기간 직접 선택 · 라이트") {
    PeriodRangeSheetPreview()
        .preferredColorScheme(.light)
}

#Preview("기간 직접 선택 · 다크") {
    PeriodRangeSheetPreview()
        .preferredColorScheme(.dark)
}

/// 세그먼트·화살표·격자가 medium detent 안에서 어디까지 밀리는지 본다.
#Preview("기간 직접 선택 · AX5") {
    PeriodRangeSheetPreview()
        .dynamicTypeSize(.accessibility5)
}
#endif
