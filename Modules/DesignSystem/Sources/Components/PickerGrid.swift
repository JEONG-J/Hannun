//
//  PickerGrid.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/6/26.
//

import SwiftUI

/// 값 목록을 3열 알약 격자로 펼쳐 하나 고르게 하는 컨트롤.
///
/// 열 개수를 열지 않은 이유는 이 격자가 **카드 폭 안에서 한 손으로 닿는 칸** 이라는 규격이기
/// 때문이다 — 3열이 곧 규격이고, 그 값이 달라지면 다른 컴포넌트다.
///
/// 선택 칸 문법(`brandTint` 채움 + `brand` 라벨)은 `SegmentedPicker` 와 같다 — 둘 다
/// "여러 값 중 지금 이것" 을 말하는 컨트롤이라 어휘를 나눠 쓴다.
///
/// `accessibilityLabel` 은 라벨만으로 값이 특정되지 않을 때 준다 — 월 격자의 `3월` 처럼
/// 년을 넘겨도 같은 글자가 반복되는 자리에서 VoiceOver 가 무엇을 읽을지 결정한다.
public struct PickerGrid<Value: Hashable>: View {

    // MARK: - Property

    private let values: [Value]
    private let selection: Value?
    private let disabled: Set<Value>
    private let label: (Value) -> String
    private let accessibilityLabel: ((Value) -> String)?
    private let onSelect: (Value) -> Void

    // MARK: - Body

    public init(
        _ values: [Value],
        selection: Value?,
        disabled: Set<Value> = [],
        label: @escaping (Value) -> String,
        accessibilityLabel: ((Value) -> String)? = nil,
        onSelect: @escaping (Value) -> Void
    ) {
        self.values = values
        self.selection = selection
        self.disabled = disabled
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: Constants.columns, spacing: .spacingXS) {
            ForEach(values, id: \.self) { value in
                cell(value)
            }
        }
    }

    // MARK: - Function

    private func cell(_ value: Value) -> some View {
        let isSelected = value == selection
        let isDisabled = disabled.contains(value)

        return Button {
            onSelect(value)
        } label: {
            Text(label(value))
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
        .accessibilityLabel(accessibilityLabel?(value) ?? label(value))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 비활성만 `textSecondary` 로 눕힌다 — 고를 수 있는 칸을 그 잉크로 적으면 둘이 같아진다.
    private func labelColor(isSelected: Bool, isDisabled: Bool) -> Color {
        if isSelected { return .brand }
        return isDisabled ? .textSecondary : .textPrimary
    }
}

fileprivate enum Constants {
    static let columnCount = 3
    static let columns = Array(
        repeating: GridItem(.flexible(), spacing: .spacingXS),
        count: columnCount
    )
    /// AX5 에서 라벨이 3등분한 열을 넘어서면 잘리는 대신 줄어든다.
    static let labelMinimumScaleFactor: CGFloat = 0.7
}

#if DEBUG
private struct PickerGridPreview: View {

    // MARK: - Property

    private let years = Array(2019...2026)
    private let unavailableYears: Set<Int> = [2019, 2020]

    @State private var selectedYear = 2026

    // MARK: - Body

    var body: some View {
        PickerGrid(
            years,
            selection: selectedYear,
            disabled: unavailableYears,
            label: { "\($0)년" },
            onSelect: { selectedYear = $0 }
        )
        .padding(.spacingL)
        .background(Color.surfacePrimary, in: .hannunContainer())
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

/// 기록이 없는 앞 두 해가 비활성으로 섞여 있다.
#Preview("칸 격자 · 라이트") {
    PickerGridPreview()
        .preferredColorScheme(.light)
}

#Preview("칸 격자 · 다크") {
    PickerGridPreview()
        .preferredColorScheme(.dark)
}

#Preview("칸 격자 · AX5") {
    PickerGridPreview()
        .dynamicTypeSize(.accessibility5)
}
#endif
