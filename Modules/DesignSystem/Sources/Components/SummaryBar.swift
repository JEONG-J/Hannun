//
//  SummaryBar.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 포트폴리오 상단 요약 바. 총액과 손익을 한 줄에 붙여 스크롤 위 공간을 최소로 쓴다.
///
/// 큰 숫자를 쓰지 않는다 — 이 화면이 답하는 질문은 "얼마인가"가 아니라 "무엇을 들고 있나"라서,
/// 총액이 종목 리스트보다 커지면 위계가 뒤집힌다.
public struct SummaryBar: View {

    // MARK: - Property

    private let title: String
    private let amount: Money
    private let change: ChangePillContent?

    // MARK: - Body

    public init(title: String, amount: Money, change: ChangePillContent? = nil) {
        self.title = title
        self.amount = amount
        self.change = change
    }

    public var body: some View {
        HStack(spacing: .spacingS) {
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(title)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                AmountText(amount, size: .row)
            }

            Spacer(minLength: .spacingS)

            if let change {
                ChangePill(change)
            }
        }
        .lineLimit(1)
        .padding(.spacingM)
        .background(Color.surfacePrimary, in: .hannunContainer())
    }
}

#if DEBUG
private struct SummaryBarPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingM) {
            SummaryBar(
                title: "총 평가금액",
                amount: .krw(128_450_000),
                change: .amountWithRatio(.krw(1_240_000), 0.0098)
            )

            SummaryBar(
                title: "총 평가금액",
                amount: .usd(96_412.50),
                change: .amountWithRatio(.usd(-1_204.35), -0.0432)
            )

            SummaryBar(title: "총 평가금액", amount: .krw(0))
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("요약 바 · 라이트") {
    SummaryBarPreview()
        .preferredColorScheme(.light)
}

#Preview("요약 바 · 다크") {
    SummaryBarPreview()
        .preferredColorScheme(.dark)
}
#endif
