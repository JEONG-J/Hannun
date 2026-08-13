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
///
/// 퍼센트 숫자만으로는 다섯 줄의 크기 차이가 읽히지 않아 아래에 같은 색 비중 막대를 깐다 —
/// 목록이 곧 도넛의 범례이므로 막대도 섹터와 같은 카테고리 색을 쓴다.
struct CategorySubtotalRow: View {

    // MARK: - Property

    private let breakdown: CategoryBreakdown
    /// 도넛에서 이 카테고리를 고른 상태. 선택이 홀 안에서만 일어나면 어느 줄 이야기인지 모른다.
    private let isSelected: Bool
    private let action: () -> Void

    // MARK: - Body

    init(_ breakdown: CategoryBreakdown, isSelected: Bool, action: @escaping () -> Void) {
        self.breakdown = breakdown
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: .spacingXS) {
                headline

                // 부채는 비중을 갖지 않는다. 게이지는 weight 0 에서도 최소 조각을 그리므로
                // 통째로 걷어내지 않으면 "아주 조금 있는 자산" 처럼 읽힌다.
                if !isLiability {
                    weightBar
                        .padding(.leading, Constants.barLeadingInset)
                }
            }
            .padding(.vertical, .spacingS)
            .padding(.horizontal, .spacingS)
            .background {
                if isSelected {
                    Color.surfaceSecondary
                        .clipShape(.hannunContainer(radius: .radiusS))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .hannunAnimation(.standard, value: isSelected)
        .accessibilityLabel(breakdown.category.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(Constants.accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Function

    private var isLiability: Bool { breakdown.category.isLiability }

    private var headline: some View {
        HStack(spacing: .spacingS) {
            CategoryDot(breakdown.category)

            Text(breakdown.category.title)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: .spacingS)

            AmountText(breakdown.amount, size: .sub)

            // 부채도 이 슬롯을 비우지 않는다 — 비우면 금액이 퍼센트 폭만큼 밀려
            // 우측 정렬된 금액 열에서 이 줄만 어긋난다.
            Text(isLiability ? Constants.liabilityCaption : weightText)
                .hannunFont(.caption, tabularFigures: !isLiability)
                .foregroundStyle(Color.textSecondary)

            Image(systemName: Constants.disclosureSymbolName)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .lineLimit(1)
    }

    /// 비중은 바로 위 퍼센트 숫자가 이미 말한다. 막대까지 읽으면 같은 값을 두 번 듣는다.
    private var weightBar: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(breakdown.category.color)
                .frame(width: proxy.size.width * barFraction)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Constants.barHeight)
        .background(Color.surfaceSecondary, in: .capsule)
        .accessibilityHidden(true)
    }

    /// 반올림해서 0% 로 보이는 자산군도 막대가 아주 조금은 남아야 줄이 비어 보이지 않는다.
    private var barFraction: CGFloat {
        let fraction = NSDecimalNumber(decimal: breakdown.weight).doubleValue
        return min(max(CGFloat(fraction), Constants.minimumBarFraction), 1)
    }

    private var weightText: String {
        breakdown.weight.formatted(
            .percent.precision(.fractionLength(Constants.weightFractionLength))
        )
    }

    /// `AmountText` 는 금액을 부호·기호·정수부·소수부로 쪼개 그려서 그대로 읽히면 토막난다.
    /// 같은 규칙으로 만든 한 문장을 값으로 얹어 대신 읽게 한다.
    private var accessibilityValue: String {
        let amount = AmountFormatter.text(for: breakdown.amount)
        // 한국어 VoiceOver 가 마이너스를 안 읽는 경우가 있다. 그러면 부채 금액이 자산으로
        // 들리므로 부호 말고 말로도 한 번 더 붙인다.
        guard !isLiability else {
            return amount + Constants.accessibilityValueSeparator + Constants.liabilityCaption
        }

        return amount
            + Constants.accessibilityValueSeparator
            + Constants.weightPrefix
            + weightText
    }
}

fileprivate enum Constants {
    static let disclosureSymbolName = "chevron.right"
    /// 시안이 정수 퍼센트다. 다섯 칸이라 소수점을 붙이면 줄이 넘친다.
    static let weightFractionLength = 0
    static let barHeight: CGFloat = 3
    /// dot(8pt) + `spacingS` 만큼 들여써서 막대가 이름 왼쪽 끝에서 시작한다.
    static let barLeadingInset: CGFloat = 16
    static let minimumBarFraction: CGFloat = 0.02
    static let accessibilityHint = "포트폴리오 탭에서 이 분류만 봅니다"
    static let accessibilityValueSeparator = ", "
    static let weightPrefix = "비중 "
    /// 퍼센트 자리를 대신 채운다. "34%"(≈24pt) 와 폭이 비슷해 금액 열이 그대로 선다.
    static let liabilityCaption = "부채"
}
