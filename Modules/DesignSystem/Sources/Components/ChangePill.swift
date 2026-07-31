//
//  ChangePill.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 손익 방향. 상승이 빨강인 것은 오타가 아니라 국내 증시 관례다 — 뒤집지 않는다.
public enum ChangeDirection: CaseIterable, Sendable {
    case gain
    case loss
    case neutral

    public init(_ value: Decimal) {
        if value > 0 {
            self = .gain
        } else if value < 0 {
            self = .loss
        } else {
            self = .neutral
        }
    }
}

public extension ChangeDirection {
    var color: Color {
        switch self {
        case .gain: .gain
        case .loss: .loss
        case .neutral: .neutral
        }
    }

    var tint: HannunTint {
        switch self {
        case .gain: .gainTint
        case .loss: .lossTint
        case .neutral: .neutralTint
        }
    }
}

/// pill 이 표시할 내용. 종목 행은 탭할 때마다 이 값을 갈아 끼워 지표를 순환시킨다.
public enum ChangePillContent: Equatable, Sendable {
    /// 수익률만. 비율을 넣는다 — `0.0098` → `+0.98%`.
    case ratio(Decimal)
    /// 수익금만.
    case amount(Money)
    /// 금액 + 수익률 병기 — `+₩1,240,000 (+0.98%)`.
    case amountWithRatio(Money, Decimal)
}

extension ChangePillContent {
    var direction: ChangeDirection {
        switch self {
        case .ratio(let ratio): ChangeDirection(ratio)
        case .amount(let money): ChangeDirection(money.amount)
        case .amountWithRatio(_, let ratio): ChangeDirection(ratio)
        }
    }

    var text: String {
        switch self {
        case .ratio(let ratio):
            AmountFormatter.percentage(ratio: ratio)
        case .amount(let money):
            AmountFormatter.text(for: money, showsPositiveSign: true)
        case .amountWithRatio(let money, let ratio):
            AmountFormatter.text(for: money, showsPositiveSign: true)
                + " (\(AmountFormatter.percentage(ratio: ratio)))"
        }
    }
}

/// 수익률·변동 표시용 tint capsule. 방향(상승/하락/보합)에 따라 글자색과 배경 tint 가 함께 바뀐다.
public struct ChangePill: View {

    // MARK: - Property

    private let content: ChangePillContent

    // MARK: - Body

    public init(_ content: ChangePillContent) {
        self.content = content
    }

    public var body: some View {
        Text(content.text)
            .hannunFont(.pillLabel)
            .foregroundStyle(content.direction.color)
            .lineLimit(1)
            .padding(.vertical, .spacingXS)
            .padding(.horizontal, .spacingS)
            .background(content.direction.tint, in: .capsule)
    }
}

#if DEBUG
private struct ChangePillPreview: View {

    // MARK: - Property

    private let contents: [ChangePillContent] = [
        .ratio(0.0098),
        .ratio(-0.0432),
        .ratio(0),
        .amount(.krw(1_240_000)),
        .amount(.krw(-820_500)),
        .amountWithRatio(.krw(1_240_000), 0.0098),
        .amountWithRatio(.usd(-1_204.35), -0.0432),
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            ForEach(Array(contents.enumerated()), id: \.offset) { _, content in
                ChangePill(content)
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }
}

#Preview("변동 pill · 라이트") {
    ChangePillPreview()
        .preferredColorScheme(.light)
}

#Preview("변동 pill · 다크") {
    ChangePillPreview()
        .preferredColorScheme(.dark)
}
#endif
