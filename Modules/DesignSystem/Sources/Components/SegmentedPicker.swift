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
/// `Value` 에 `Sendable` 을 요구하는 이유는 아래 `row(isEvenlyDivided:)` 주석에 있다.
public struct SegmentedPicker<Value: Hashable & Sendable>: View {

    // MARK: - Property

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let values: [Value]
    private let label: @Sendable (Value) -> String

    @Binding private var selection: Value

    // MARK: - Body

    public init(
        _ values: [Value],
        selection: Binding<Value>,
        label: @escaping @Sendable (Value) -> String
    ) {
        self.values = values
        self.label = label
        _selection = selection
    }

    /// 서체와 버튼 스타일은 세그먼트마다 붙이지 않고 트랙에 한 번 건다 — 둘 다 환경으로 흘러
    /// 하위 `Text`·`Button` 에 그대로 닿고, 아래 `row(isEvenlyDivided:)` 가 메인 액터를 벗어날 수 있다.
    public var body: some View {
        track
            .hannunFont(.pillLabel)
            .buttonStyle(.plain)
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

    /// `ForEach` 의 내용 클로저는 `nonisolated` 로 만든다 — 여기가 이 컨트롤의 크래시 지점이었다.
    ///
    /// `View` 프로토콜이 `@preconcurrency @MainActor` 라 이 타입 전체가 `@MainActor` 로 추론되는데,
    /// `ForEach.content` 는 격리 없는 `(Data.Element) -> Content` 다. `@MainActor` 클로저를 그 자리에
    /// 넣으면 컴파일러가 **런타임 실행자 검사**를 심고, SwiftUI 가 `com.apple.SwiftUI.AsyncRenderer`
    /// 스레드에서 레이아웃을 돌며 이 지연 클로저를 당기는 순간 `dispatch_assert_queue` 로 트랩한다.
    /// 애니메이션이 붙은 차트 헤더에 들어갔을 때 실제로 터졌다.
    ///
    /// 뷰를 조립하는 순수 계산이라 메인 액터가 필요 없다 (`CalendarHeatmap` 의 `nonisolated` 와 같은 이유).
    /// 격리를 떼면 검사가 사라져 어느 스레드가 당겨도 안전하다 — 대신 `self` 를 건너보내야 하므로
    /// `Value: Sendable`(→ `Binding` 도 Sendable) 과 `@Sendable` 라벨이 따라온다.
    nonisolated private func row(isEvenlyDivided: Bool) -> some View {
        let selection = _selection.wrappedValue

        return HStack(spacing: 0) {
            ForEach(values, id: \.self) {
                segment($0, isSelected: $0 == selection, isEvenlyDivided: isEvenlyDivided)
            }
        }
        .padding(Constants.trackPadding)
    }

    nonisolated private func segment(
        _ value: Value,
        isSelected: Bool,
        isEvenlyDivided: Bool
    ) -> some View {
        Button {
            _selection.wrappedValue = value
        } label: {
            Text(label(value))
                .foregroundStyle(isSelected ? Color.brand : Color.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: !isEvenlyDivided, vertical: false)
                .padding(.horizontal, isEvenlyDivided ? 0 : .spacingM)
                .frame(
                    maxWidth: isEvenlyDivided ? .infinity : nil,
                    minHeight: .minimumTouchTarget
                )
                .background {
                    if isSelected {
                        Capsule().fill(HannunTint.brandTint)
                    }
                }
                .contentShape(.capsule)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
