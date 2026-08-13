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
    /// 대출이 들어오면 이 숫자는 자산의 합이 아니라 자산 − 부채다.
    static let accessibilityLabel = "순자산"
    static let valueSeparator = ", "
    static let changePrefix = "전일 대비 "
}

#if DEBUG
@MainActor
private func negativeTotalPreview() -> some View {
    TotalAssetBlock(
        total: .krw(-8_420_000),
        change: NetWorthChange(amount: .krw(-320_000), ratio: -0.039)
    )
    .padding(.spacingL)
    .background(Color.backgroundPrimary)
}

/// 대출이 자산을 넘긴 계정. 마이너스 글리프가 통화기호처럼 죽지 않고 숫자와 같은 무게로
/// 보여야 한다 — 색 말고는 부채라는 단서가 이 부호뿐이다.
#Preview("순자산 · 음수") {
    negativeTotalPreview()
}

/// 34pt 숫자가 AX5 에서 몇 배가 된다. 부호가 잘리거나 pill 이 밖으로 밀리면 회귀다.
#Preview("순자산 · 음수 · AX5") {
    negativeTotalPreview()
        .dynamicTypeSize(.accessibility5)
}
#endif
