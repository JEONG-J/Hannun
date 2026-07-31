//
//  CategorySectionHeader.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 카테고리 그룹 헤더. dot 은 도넛 섹터와 같은 토큰이라 헤더 자체가 범례 노릇을 한다.
public struct CategorySectionHeader: View {

    // MARK: - Property

    private let category: AssetCategory
    private let title: String
    private let subtotal: Money
    @Binding private var isExpanded: Bool

    // MARK: - Body

    public init(
        category: AssetCategory,
        title: String,
        subtotal: Money,
        isExpanded: Binding<Bool>
    ) {
        self.category = category
        self.title = title
        self.subtotal = subtotal
        _isExpanded = isExpanded
    }

    public var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: .spacingS) {
                CategoryDot(category)

                Text(title)
                    .hannunFont(.subtext)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: .spacingS)

                AmountText(subtotal, size: .sub)

                Image(systemName: Constants.chevronSymbolName)
                    .hannunFont(.subtext)
                    .foregroundStyle(Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : Constants.collapsedChevronDegrees))
            }
            .lineLimit(1)
            .padding(.vertical, .spacingS)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .hannunAnimation(.standard, value: isExpanded)
        .accessibilityLabel(title)
        .accessibilityValue(AmountFormatter.text(for: subtotal))
    }
}

fileprivate enum Constants {
    static let chevronSymbolName = "chevron.down"
    static let collapsedChevronDegrees: Double = -90
}

#if DEBUG
private struct CategorySectionHeaderPreview: View {

    // MARK: - Property

    @State private var isDomesticExpanded = true
    @State private var isCashExpanded = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingM) {
            VStack(spacing: 0) {
                CategorySectionHeader(
                    category: .domesticStock,
                    title: "국내주식",
                    subtotal: .krw(43_673_000),
                    isExpanded: $isDomesticExpanded
                )
                .padding(.horizontal, .spacingL)

                if isDomesticExpanded {
                    HoldingRow(
                        name: "삼성전자",
                        ticker: "005930",
                        subline: "10주 · ₩61,300",
                        amount: .krw(6_910_000),
                        change: .ratio(0.0484)
                    )
                }
            }
            .padding(.vertical, .spacingS)
            .background(Color.surfacePrimary, in: .hannunContainer())

            VStack(spacing: 0) {
                CategorySectionHeader(
                    category: .cash,
                    title: "현금",
                    subtotal: .krw(12_845_000),
                    isExpanded: $isCashExpanded
                )
                .padding(.horizontal, .spacingL)

                if isCashExpanded {
                    HoldingRow(name: "원화 예수금", amount: .krw(12_845_000))
                }
            }
            .padding(.vertical, .spacingS)
            .background(Color.surfacePrimary, in: .hannunContainer())
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("카테고리 헤더 · 라이트") {
    CategorySectionHeaderPreview()
        .preferredColorScheme(.light)
}

#Preview("카테고리 헤더 · 다크") {
    CategorySectionHeaderPreview()
        .preferredColorScheme(.dark)
}
#endif
