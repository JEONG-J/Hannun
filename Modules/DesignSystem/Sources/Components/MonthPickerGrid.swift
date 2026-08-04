//
//  MonthPickerGrid.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/4/26.
//

import SwiftUI

/// 한 해 열두 달을 3열 격자로 펼쳐 고르게 하는 컨트롤.
///
/// 캘린더 카드가 **일 격자 자리에서 그대로 뒤집혀** 이 격자가 된다. 시트로 띄우지 않는 이유는
/// 셀 상세를 시트로 하지 않은 이유와 같다 — 이 탭엔 이미 기간·벤치마크 시트가 둘이라
/// 세 번째 모달을 얹으면 "어느 시트가 무엇을 고르는지" 를 기억해야 한다.
///
/// 선택 칸 문법(`brandTint` 채움 + `brand` 라벨)은 `SegmentedPicker` 와 같다 — 둘 다
/// "여러 값 중 지금 이것" 을 말하는 컨트롤이라 어휘를 나눠 쓴다.
///
/// `year` 는 격자에 그리지 않는다(헤더가 이미 말한다). 대신 접근성 라벨이 이 값을 써
/// `2026년 3월` 로 읽는다 — 년 이동으로 같은 `3월` 이 반복되므로 어느 해인지 없으면
/// VoiceOver 만으로는 구분되지 않는다.
public struct MonthPickerGrid: View {

    // MARK: - Property

    private let year: Int
    private let selectedMonth: Int?
    private let disabledMonths: Set<Int>
    private let onSelect: (Int) -> Void

    // MARK: - Body

    public init(
        year: Int,
        selectedMonth: Int?,
        disabledMonths: Set<Int>,
        onSelect: @escaping (Int) -> Void
    ) {
        self.year = year
        self.selectedMonth = selectedMonth
        self.disabledMonths = disabledMonths
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: Constants.columns, spacing: .spacingXS) {
            ForEach(Constants.months, id: \.self) { month in
                monthButton(month)
            }
        }
    }

    // MARK: - Function

    private func monthButton(_ month: Int) -> some View {
        let isSelected = month == selectedMonth
        let isDisabled = disabledMonths.contains(month)

        return Button {
            onSelect(month)
        } label: {
            Text(Constants.title(ofMonth: month))
                .hannunFont(.pillLabel)
                .foregroundStyle(labelColor(isSelected: isSelected, isDisabled: isDisabled))
                .lineLimit(1)
                .minimumScaleFactor(Constants.labelMinimumScaleFactor)
                .frame(maxWidth: .infinity, minHeight: .minimumTouchTarget)
                .background {
                    if isSelected {
                        Capsule().fill(HannunTint.brandTint)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(Constants.accessibilityLabel(year: year, month: month))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 비활성만 `textSecondary` 로 눕힌다 — 고를 수 있는 달을 그 잉크로 적으면 둘이 같아진다.
    private func labelColor(isSelected: Bool, isDisabled: Bool) -> Color {
        if isSelected { return .brand }
        return isDisabled ? .textSecondary : .textPrimary
    }
}

fileprivate enum Constants {
    static let months = Array(1...12)
    static let columnCount = 3
    static let columns = Array(
        repeating: GridItem(.flexible(), spacing: .spacingXS),
        count: columnCount
    )
    /// AX5 에서 `12월` 이 3등분한 열을 넘어서면 잘리는 대신 줄어든다.
    static let labelMinimumScaleFactor: CGFloat = 0.7

    static func title(ofMonth month: Int) -> String {
        "\(month)월"
    }

    static func accessibilityLabel(year: Int, month: Int) -> String {
        "\(year)년 \(month)월"
    }
}

#if DEBUG
private struct MonthPickerGridPreview: View {

    // MARK: - Property

    private let year: Int
    private let disabledMonths: Set<Int>

    @State private var selectedMonth: Int

    // MARK: - Body

    init(year: Int, selectedMonth: Int, disabledMonths: Set<Int>) {
        self.year = year
        self.disabledMonths = disabledMonths
        _selectedMonth = State(initialValue: selectedMonth)
    }

    var body: some View {
        VStack(spacing: .spacingM) {
            Text(verbatim: "\(year)년")
                .hannunFont(.sectionHeading)
                .foregroundStyle(Color.textPrimary)

            MonthPickerGrid(
                year: year,
                selectedMonth: selectedMonth,
                disabledMonths: disabledMonths
            ) { selectedMonth = $0 }
        }
        .padding(.spacingL)
        .background(Color.surfacePrimary, in: .hannunContainer())
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

/// 올해 — 이번 달(8월) 다음부터 비활성이다.
#Preview("월 선택 격자 · 올해") {
    MonthPickerGridPreview(year: 2026, selectedMonth: 7, disabledMonths: Set(9...12))
}

/// 지난 년 — 열두 달이 전부 활성이다.
#Preview("월 선택 격자 · 과거 년") {
    MonthPickerGridPreview(year: 2025, selectedMonth: 3, disabledMonths: [])
}

#Preview("월 선택 격자 · AX5") {
    MonthPickerGridPreview(year: 2026, selectedMonth: 7, disabledMonths: Set(9...12))
        .dynamicTypeSize(.accessibility5)
}
#endif
