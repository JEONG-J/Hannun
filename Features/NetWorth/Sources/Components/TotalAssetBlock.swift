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
        .accessibilityElement(children: .combine)
    }
}
