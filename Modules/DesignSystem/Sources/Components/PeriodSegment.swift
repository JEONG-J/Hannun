//
//  PeriodSegment.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 추이 차트가 그리는 구간. 차트 축과 직결된 컨트롤의 어휘라 디자인 시스템이 갖는다.
public enum ChartPeriod: String, CaseIterable, Identifiable, Sendable {
    case oneMonth
    case threeMonths
    case sixMonths
    case yearToDate
    case oneYear
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .yearToDate: "YTD"
        case .oneYear: "1Y"
        case .all: "ALL"
        }
    }
}

/// 기간 선택 세그먼트. 차트 바로 아래 인라인 전용이다.
///
/// 액세서리로 올리지 않는다 — 그 자리는 벤치마크 칩이 쓰고, 358pt 캡슐에 둘을 같이 넣으면
/// 어느 쪽도 44pt 터치 타깃을 못 지킨다. 기간은 축을 바꾸는 컨트롤이라 차트에 붙는 편이 맞다.
public struct PeriodSegment: View {

    // MARK: - Property

    @Binding private var selection: ChartPeriod

    // MARK: - Body

    public init(selection: Binding<ChartPeriod>) {
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartPeriod.allCases) { period in
                Button {
                    selection = period
                } label: {
                    Text(period.title)
                        .hannunFont(.pillLabel)
                        .foregroundStyle(period == selection ? Color.brand : Color.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacingS)
                        .background {
                            if period == selection {
                                Capsule().fill(HannunTint.brandTint)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Constants.trackPadding)
        .hannunGlass(.periodSegment)
        .hannunAnimation(.selection, value: selection)
    }
}

fileprivate enum Constants {
    /// 선택 캡슐이 glass 트랙 테두리에 닿지 않게 하는 최소 여백.
    static let trackPadding: CGFloat = 4
}

#if DEBUG
private struct PeriodSegmentPreview: View {

    // MARK: - Property

    @State private var selection: ChartPeriod = .yearToDate

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            Text("선택: \(selection.title)")
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)

            PeriodSegment(selection: $selection)
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("기간 세그먼트 · 라이트") {
    PeriodSegmentPreview()
        .preferredColorScheme(.light)
}

#Preview("기간 세그먼트 · 다크") {
    PeriodSegmentPreview()
        .preferredColorScheme(.dark)
}
#endif
