//
//  SegmentedPicker.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/4/26.
//

import SwiftUI

/// 값 목록을 한 줄 세그먼트로 펼쳐 고르게 하는 컨트롤.
///
/// 선택지를 **동시에 다 보여 주고 한 번에 고르게** 하는 자리에 쓴다 — 차트 축을 바꾸는 단위,
/// 구간 기간처럼 콘텐츠 영역의 컨트롤이다. 액세서리 캡슐 안에는 쓰지 않는다: 그 안의 컨트롤은
/// 하나뿐이어야 하고 재질도 겹치면 안 된다(UI 스펙 §3.1).
///
/// 값 타입을 제네릭으로 연 이유는 모듈 경계다. DesignSystem 은 Domain 을 모르므로
/// `TrendGranularity` 같은 타입을 직접 받을 수 없다 — 라벨 클로저로 호출부가 특수화한다.
///
/// ```swift
/// SegmentedPicker(TrendGranularity.allCases, selection: $granularity) { $0.title }
/// ```
public struct SegmentedPicker<Value: Hashable>: View {

    // MARK: - Property

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let values: [Value]
    private let label: (Value) -> String

    @Binding private var selection: Value

    // MARK: - Body

    public init(
        _ values: [Value],
        selection: Binding<Value>,
        label: @escaping (Value) -> String
    ) {
        self.values = values
        self.label = label
        _selection = selection
    }

    public var body: some View {
        track
            .hannunGlass(.periodSegment)
            .hannunAnimation(.selection, value: selection)
    }

    // MARK: - Function

    /// AX 사이즈에서는 등분한 열이 라벨을 담지 못해 하필 **선택된** 칸이 먼저 잘린다.
    /// 지금 무엇을 보고 있는지 말하는 유일한 단서라 줄일 수 없다 — 열 폭을 라벨에 맞추고
    /// 트랙째 가로로 굴린다.
    @ViewBuilder
    private var track: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) { row(isEvenlyDivided: false) }
                .scrollIndicators(.hidden)
        } else {
            row(isEvenlyDivided: true)
        }
    }

    private func row(isEvenlyDivided: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { segment($0, isEvenlyDivided: isEvenlyDivided) }
        }
        .padding(Constants.trackPadding)
    }

    private func segment(_ value: Value, isEvenlyDivided: Bool) -> some View {
        Button {
            selection = value
        } label: {
            Text(label(value))
                .hannunFont(.pillLabel)
                .foregroundStyle(value == selection ? Color.brand : Color.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: !isEvenlyDivided, vertical: false)
                .padding(.horizontal, isEvenlyDivided ? 0 : .spacingM)
                .frame(
                    maxWidth: isEvenlyDivided ? .infinity : nil,
                    minHeight: .minimumTouchTarget
                )
                .background {
                    if value == selection {
                        Capsule().fill(HannunTint.brandTint)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(value == selection ? .isSelected : [])
    }
}

fileprivate enum Constants {
    /// 선택 캡슐이 glass 트랙 테두리에 닿지 않게 하는 최소 여백.
    static let trackPadding: CGFloat = 4
}

#if DEBUG
private struct SegmentedPickerPreview: View {

    // MARK: - Property

    @State private var granularity = "일별"
    @State private var period: ChartPeriod = .yearToDate

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            VStack(alignment: .leading, spacing: .spacingS) {
                Text("2칸 · 단위")
                    .hannunFont(.subtext)
                    .foregroundStyle(Color.textSecondary)

                SegmentedPicker(["일별", "월별"], selection: $granularity) { $0 }
            }

            VStack(alignment: .leading, spacing: .spacingS) {
                Text("6칸 · 기간")
                    .hannunFont(.subtext)
                    .foregroundStyle(Color.textSecondary)

                SegmentedPicker(ChartPeriod.allCases, selection: $period) { $0.title }
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("세그먼트 피커 · 라이트") {
    SegmentedPickerPreview()
        .preferredColorScheme(.light)
}

#Preview("세그먼트 피커 · 다크") {
    SegmentedPickerPreview()
        .preferredColorScheme(.dark)
}

/// 등분 대신 라벨 폭 + 가로 스크롤로 넘어가는지 확인한다.
#Preview("세그먼트 피커 · AX5") {
    SegmentedPickerPreview()
        .dynamicTypeSize(.accessibility5)
}
#endif
