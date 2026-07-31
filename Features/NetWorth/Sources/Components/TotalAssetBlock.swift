//
//  TotalAssetBlock.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import SwiftUI

/// NW-1 총자산 블록. 화면에서 가장 큰 숫자 하나와 전일 대비 변동만 둔다.
///
/// 배경을 깔지 않는다 — 금액 블록은 배경 위에 그대로 얹는 것이 UI 스펙의 glass 규칙이다.
struct TotalAssetBlock: View {

    // MARK: - Property

    private let total: Money
    private let change: NetWorthChange?

    // MARK: - Body

    init(total: Money, change: NetWorthChange?) {
        self.total = total
        self.change = change
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            AmountText(total, size: .display)

            if let change {
                ChangePill(.amountWithRatio(change.amount, change.ratio))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Function

    /// 자식을 합치면 `AmountText` 가 쪼개 그린 조각들이 토막난 채 읽힌다.
    /// 화면에 찍히는 것과 같은 규칙으로 만든 한 문장을 대신 얹는다.
    private var accessibilityValue: String {
        let amount = AmountFormatter.text(for: total)
        guard let change else { return amount }

        let pill = ChangePillContent.amountWithRatio(change.amount, change.ratio)
        return amount + Constants.valueSeparator + Constants.changePrefix + pill.text
    }
}

fileprivate enum Constants {
    static let accessibilityLabel = "총자산"
    static let valueSeparator = ", "
    static let changePrefix = "전일 대비 "
}
