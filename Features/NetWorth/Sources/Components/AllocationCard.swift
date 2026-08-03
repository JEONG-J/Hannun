//
//  AllocationCard.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// NW-3 비중 도넛과 NW-4 카테고리 소계를 한 면에 묶는다.
///
/// 도넛 섹터와 아래 dot 이 같은 색 토큰을 쓰므로 리스트가 곧 범례다 — 범례를 따로 두지 않는다.
/// 면은 불투명이다. 차트·리스트 뒤에 glass 를 깔면 섹터 색과 배경이 섞인다.
struct AllocationCard: View {

    // MARK: - Property

    private let breakdown: [CategoryBreakdown]
    @Binding private var selection: AssetCategory?
    private let onSelect: (AssetCategory) -> Void

    // MARK: - Body

    init(
        breakdown: [CategoryBreakdown],
        selection: Binding<AssetCategory?>,
        onSelect: @escaping (AssetCategory) -> Void
    ) {
        self.breakdown = breakdown
        _selection = selection
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: .spacingM) {
            DonutChart(
                slices: breakdown.map {
                    DonutChartSlice(
                        category: $0.category,
                        name: $0.category.title,
                        amount: $0.amount
                    )
                },
                selection: $selection
            )

            Rectangle()
                .fill(Color.separator)
                .frame(height: Constants.separatorHeight)

            VStack(spacing: 0) {
                ForEach(breakdown) { item in
                    CategorySubtotalRow(item, isSelected: selection == item.category) {
                        onSelect(item.category)
                    }
                }
            }
        }
        .padding(.spacingM)
        .hannunGlass(.contentSurface, in: .hannunContainer())
    }
}

fileprivate enum Constants {
    static let separatorHeight: CGFloat = 1
}

#if DEBUG
private struct AllocationCardPreview: View {

    // MARK: - Property

    /// 화면과 같은 금액 내림차순. 시안(§6.1)의 34 / 26 / 18 / 12 / 10 구성이다.
    private let breakdown: [CategoryBreakdown] = [
        CategoryBreakdown(category: .domesticStock, amount: .krw(43_673_000), weight: 0.34),
        CategoryBreakdown(category: .overseasStock, amount: .krw(33_397_000), weight: 0.26),
        CategoryBreakdown(category: .etf, amount: .krw(23_121_000), weight: 0.18),
        CategoryBreakdown(category: .crypto, amount: .krw(15_414_000), weight: 0.12),
        CategoryBreakdown(category: .cash, amount: .krw(12_845_000), weight: 0.10),
    ]

    @State private var selection: AssetCategory?

    // MARK: - Body

    var body: some View {
        ScrollView {
            AllocationCard(breakdown: breakdown, selection: $selection) { _ in }
            .padding(.spacingL)
        }
        .background(Color.backgroundPrimary)
    }
}

#Preview("자산군 비중 · 라이트") {
    AllocationCardPreview()
        .preferredColorScheme(.light)
}

#Preview("자산군 비중 · 다크") {
    AllocationCardPreview()
        .preferredColorScheme(.dark)
}
#endif
