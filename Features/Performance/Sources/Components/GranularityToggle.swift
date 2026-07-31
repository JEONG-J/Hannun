//
//  GranularityToggle.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import HannunDomain
import SwiftUI

extension TrendGranularity {
    var title: String {
        switch self {
        case .daily: "일별"
        case .monthly: "월별"
        }
    }
}

/// 추이 차트의 시간 단위 토글 (PM-2). 기간 세그먼트와 같은 행에 놓인다.
///
/// 시안의 "선택 = surface 채움 + 미세 그림자" 대신 옆에 붙는 `PeriodSegment` 와 같은
/// glass 트랙 + brand tint 로 그린다 — 새 그림자 토큰을 만들지 않고 한 행의 두 컨트롤이
/// 같은 어휘를 쓰게 하려는 선택이다.
struct GranularityToggle: View {

    // MARK: - Property

    @Binding private var selection: TrendGranularity

    // MARK: - Body

    init(selection: Binding<TrendGranularity>) {
        _selection = selection
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrendGranularity.allCases, id: \.self) { granularity in
                button(for: granularity)
            }
        }
        .padding(Constants.trackPadding)
        .hannunGlass(.periodSegment)
        .hannunAnimation(.selection, value: selection)
    }

    // MARK: - Function

    private func button(for granularity: TrendGranularity) -> some View {
        let isSelected = granularity == selection

        return Button {
            selection = granularity
        } label: {
            Text(granularity.title)
                .hannunFont(.pillLabel)
                .foregroundStyle(isSelected ? Color.brand : Color.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, Constants.labelHorizontalPadding)
                .frame(minHeight: .minimumTouchTarget)
                .background {
                    if isSelected {
                        Capsule().fill(HannunTint.brandTint)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

fileprivate enum Constants {
    /// 선택 캡슐이 glass 트랙 테두리에 닿지 않게 하는 최소 여백. `PeriodSegment` 와 같은 값이다.
    static let trackPadding: CGFloat = 4
    static let labelHorizontalPadding: CGFloat = 14
}

#if DEBUG
private struct GranularityTogglePreview: View {

    // MARK: - Property

    @State private var granularity: TrendGranularity = .daily
    @State private var period: ChartPeriod = .yearToDate

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            GranularityToggle(selection: $granularity)

            HStack(spacing: .spacingM) {
                GranularityToggle(selection: $granularity)
                PeriodSegment(selection: $period)
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("단위 토글 · 라이트") {
    GranularityTogglePreview()
        .preferredColorScheme(.light)
}

#Preview("단위 토글 · 다크") {
    GranularityTogglePreview()
        .preferredColorScheme(.dark)
}
#endif
