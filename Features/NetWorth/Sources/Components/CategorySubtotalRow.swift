//
//  CategorySubtotalRow.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// NW-4 카테고리 소계 한 줄. 누르면 포트폴리오 탭이 이 카테고리로 필터링된 채 열린다.
struct CategorySubtotalRow: View {

    // MARK: - Property

    private let breakdown: CategoryBreakdown
    private let action: () -> Void

    // MARK: - Body

    init(_ breakdown: CategoryBreakdown, action: @escaping () -> Void) {
        self.breakdown = breakdown
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spacingS) {
                CategoryDot(breakdown.category)

                Text(breakdown.category.name)
                    .hannunFont(.subtext)
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: .spacingS)

                AmountText(breakdown.amount, size: .sub)

                Text(weightText)
                    .hannunFont(.caption, tabularFigures: true)
                    .foregroundStyle(Color.textSecondary)

                Image(systemName: Constants.disclosureSymbolName)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .lineLimit(1)
            .padding(.vertical, .spacingS)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Constants.accessibilityHint)
    }

    // MARK: - Function

    private var weightText: String {
        breakdown.weight.formatted(
            .percent.precision(.fractionLength(Constants.weightFractionLength))
        )
    }
}

fileprivate enum Constants {
    static let disclosureSymbolName = "chevron.right"
    /// 시안이 정수 퍼센트다. 다섯 칸이라 소수점을 붙이면 줄이 넘친다.
    static let weightFractionLength = 0
    static let accessibilityHint = "포트폴리오 탭에서 이 자산군만 봅니다"
}
