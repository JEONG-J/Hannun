//
//  AmountText.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 금액 텍스트의 크기 변형. 세 값 모두 tabular 가 고정된 타이포 토큰에 얹힌다.
public enum AmountTextSize: CaseIterable, Sendable {
    /// 총자산·YTD 큰 숫자 (34).
    case display
    /// 행 우측 평가금액 (17).
    case row
    /// 소계·보조 금액 (13).
    case sub
}

extension AmountTextSize {
    var textStyle: HannunTextStyle {
        switch self {
        case .display: .displayAmount
        case .row: .rowAmount
        case .sub: .caption
        }
    }
}

/// 금액 표시. 통화기호와 소수부를 한 단계 죽여 숫자 본체에 위계를 준다.
///
/// 우측 정렬은 이 뷰가 폭을 잡지 않고 배치하는 쪽(`HoldingRow`·`SummaryBar`)이 책임진다 —
/// 큰 숫자 블록은 좌측 정렬이라 컴포넌트가 `maxWidth: .infinity` 를 물면 오히려 레이아웃을 망친다.
public struct AmountText: View {

    // MARK: - Property

    private let money: Money
    private let size: AmountTextSize
    private let showsPositiveSign: Bool

    // MARK: - Body

    public init(_ money: Money, size: AmountTextSize = .row, showsPositiveSign: Bool = false) {
        self.money = money
        self.size = size
        self.showsPositiveSign = showsPositiveSign
    }

    public var body: some View {
        let parts = AmountFormatter.parts(for: money, showsPositiveSign: showsPositiveSign)

        return Text(attributed(from: parts))
            .hannunFont(size.textStyle, tabularFigures: true)
            .lineLimit(1)
            .accessibilityLabel(parts.text)
    }

    // MARK: - Function

    /// 색이 다른 조각을 `Text` 로 이어 붙이는 방식은 iOS 26 에서 폐기됐다. 런 단위로 색을 주는
    /// `AttributedString` 이 대체 경로다.
    private func attributed(from parts: AmountFormatter.Parts) -> AttributedString {
        // 부호는 통화기호와 달리 값의 일부다 — 죽이면 부채 금액이 자산으로 읽힌다.
        var result = dominant(parts.sign)
        result.append(subordinate(parts.symbol))
        result.append(dominant(parts.integer))
        result.append(subordinate(parts.fraction))
        return result
    }

    private func dominant(_ text: String) -> AttributedString {
        var run = AttributedString(text)
        run.foregroundColor = .textPrimary
        return run
    }

    private func subordinate(_ text: String) -> AttributedString {
        var run = AttributedString(text)
        run.foregroundColor = .textSecondary
        return run
    }
}

#if DEBUG
private struct AmountTextPreview: View {

    // MARK: - Property

    private let wonAmount = Money.krw(128_450_000)
    private let dollarAmount = Money.usd(96_412.50)
    private let negativeAmount = Money.krw(-1_240_000)

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXL) {
            AmountText(wonAmount, size: .display)

            VStack(alignment: .trailing, spacing: .spacingS) {
                AmountText(wonAmount, size: .row)
                AmountText(dollarAmount, size: .row)
                AmountText(negativeAmount, size: .row)
                AmountText(dollarAmount, size: .sub)
                AmountText(wonAmount, size: .sub, showsPositiveSign: true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }
}

#Preview("금액 표시 · 라이트") {
    AmountTextPreview()
        .preferredColorScheme(.light)
}

#Preview("금액 표시 · 다크") {
    AmountTextPreview()
        .preferredColorScheme(.dark)
}
#endif
