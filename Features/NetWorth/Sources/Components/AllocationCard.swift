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
/// 자산군 행은 도넛 섹터와 같은 색 토큰을 써서 그대로 범례가 된다. 부채 행만 대응 섹터가
/// 없어 구분선 아래로 갈라 둔다 — 도넛에 없는 색이 범례처럼 섞이면 안 된다.
/// 면은 불투명이다. 차트·리스트 뒤에 glass 를 깔면 섹터 색과 배경이 섞인다.
struct AllocationCard: View {

    // MARK: - Property

    private let rows: [CategoryBreakdown]
    @Binding private var selection: AssetCategory?
    private let onSelect: (AssetCategory) -> Void

    // MARK: - Body

    init(
        rows: [CategoryBreakdown],
        selection: Binding<AssetCategory?>,
        onSelect: @escaping (AssetCategory) -> Void
    ) {
        self.rows = rows
        _selection = selection
        self.onSelect = onSelect
    }

    var body: some View {
        // 부채는 섹터로 그리지 않는다 — 절대값으로 그리면 "전체의 몇 %" 라는 도넛의
        // 유일한 의미가 자산 %와 부채 %의 혼합이 되어 읽을 수 없는 차트가 된다.
        let slices = assetRows.map {
            DonutChartSlice(category: $0.category, name: $0.category.title, amount: $0.amount)
        }

        return VStack(spacing: .spacingM) {
            // 대출만 있으면 그릴 섹터가 없다. 빈 200pt 공백에 홀 안내만 남으므로 통째로 뺀다.
            if !slices.isEmpty {
                DonutChart(slices: slices, selection: $selection)

                divider
            }

            VStack(spacing: 0) {
                ForEach(assetRows) { subtotalRow($0) }

                if !liabilityRows.isEmpty {
                    divider
                        .padding(.vertical, .spacingXS)

                    ForEach(liabilityRows) { subtotalRow($0) }
                }
            }
        }
        .padding(.spacingM)
        .hannunGlass(.contentSurface, in: .hannunContainer())
    }

    // MARK: - Function

    private var assetRows: [CategoryBreakdown] { rows.filter { !$0.category.isLiability } }
    private var liabilityRows: [CategoryBreakdown] { rows.filter { $0.category.isLiability } }

    private var divider: some View {
        Rectangle()
            .fill(Color.separator)
            .frame(height: Constants.separatorHeight)
    }

    private func subtotalRow(_ item: CategoryBreakdown) -> some View {
        CategorySubtotalRow(item, isSelected: selection == item.category) {
            onSelect(item.category)
        }
    }
}

fileprivate enum Constants {
    static let separatorHeight: CGFloat = 1
}

#if DEBUG
private struct AllocationCardPreview: View {

    // MARK: - Property

    private let rows: [CategoryBreakdown]

    @State private var selection: AssetCategory?

    // MARK: - Body

    init(rows: [CategoryBreakdown] = AllocationCardPreview.withLoan) {
        self.rows = rows
    }

    var body: some View {
        ScrollView {
            AllocationCard(rows: rows, selection: $selection) { _ in }
            .padding(.spacingL)
        }
        .background(Color.backgroundPrimary)
    }
}

extension AllocationCardPreview {
    /// 화면과 같은 금액 내림차순. 시안(§6.1)의 34 / 26 / 18 / 12 / 10 구성에 부채 한 줄을 붙였다 —
    /// 대출은 도넛에서 빠지고 구분선 아래에 게이지 없이 "부채" 캡션과 음수 금액만 남아야 한다.
    static let withLoan: [CategoryBreakdown] = [
        CategoryBreakdown(category: .domesticStock, amount: .krw(43_673_000), weight: 0.34),
        CategoryBreakdown(category: .overseasStock, amount: .krw(33_397_000), weight: 0.26),
        CategoryBreakdown(category: .etf, amount: .krw(23_121_000), weight: 0.18),
        CategoryBreakdown(category: .crypto, amount: .krw(15_414_000), weight: 0.12),
        CategoryBreakdown(category: .cash, amount: .krw(12_845_000), weight: 0.10),
        CategoryBreakdown(category: .loan, amount: .krw(-30_000_000), weight: 0),
    ]

    /// 대출만 있는 계정. 그릴 섹터가 없다.
    static let onlyLoan: [CategoryBreakdown] = [
        CategoryBreakdown(category: .loan, amount: .krw(-30_000_000), weight: 0),
    ]
}

#Preview("자산군 비중 · 라이트") {
    AllocationCardPreview()
        .preferredColorScheme(.light)
}

#Preview("자산군 비중 · 다크") {
    AllocationCardPreview()
        .preferredColorScheme(.dark)
}

/// 금액·퍼센트·"부채" 캡션이 한 줄에 다 못 들어가는 크기다. 행이 접히더라도 금액이
/// 잘리거나 카드 밖으로 밀리지 않아야 한다.
#Preview("자산군 비중 · AX5") {
    AllocationCardPreview()
        .dynamicTypeSize(.accessibility5)
}

/// 도넛과 그 아래 구분선이 통째로 빠지고 부채 한 줄만 남아야 한다 —
/// 200pt 빈 공백이 보이면 회귀다.
#Preview("자산군 비중 · 대출만") {
    AllocationCardPreview(rows: AllocationCardPreview.onlyLoan)
}
#endif
