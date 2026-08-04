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

/// 기간 선택 세그먼트. 차트 바로 아래 인라인 배치를 위한 컴포넌트다.
///
/// 성과 탭은 기간이 잦은 조작이라 액세서리(캡션 → 시트)로 옮겨 갔지만, 인라인 기간 선택이
/// 더 맞는 화면을 위해 이 컴포넌트 자체는 남겨 둔다.
///
/// 시각 문법은 `SegmentedPicker` 가 갖는다 — 여기는 `ChartPeriod` 특수화만 한다. 세그먼트가
/// 두 벌로 갈라지면 선택 캡슐 하나를 고쳐도 한쪽만 바뀐다.
public struct PeriodSegment: View {

    // MARK: - Property

    @Binding private var selection: ChartPeriod

    // MARK: - Body

    public init(selection: Binding<ChartPeriod>) {
        _selection = selection
    }

    public var body: some View {
        SegmentedPicker(ChartPeriod.allCases, selection: $selection) { $0.title }
    }
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
