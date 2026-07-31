//
//  AmountFormatting.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 행 보조 문구(수량·평단가·현재가)에 쓰는 문자열 변환.
///
/// 주 금액은 `AmountText` 가 그리므로 여기서 만드는 건 그 옆에 붙는 작은 텍스트뿐이다.
/// DesignSystem 의 `AmountFormatter` 가 internal 이라 같은 규칙을 이 탭에서 다시 세운다.
enum AmountFormatting {

    // MARK: - Function

    static func text(for money: Money) -> String {
        symbol(for: money.currency) + magnitudeText(money)
    }

    /// 소수 자릿수를 값에 맞춰 줄인다 — 10주는 `10`, 0.0521 BTC 는 `0.0521` 로 찍힌다.
    static func quantity(_ value: Decimal, unit: String?) -> String {
        let number = value.formatted(
            .number
                .precision(.fractionLength(0...Constants.maximumQuantityFractionDigits))
                .grouping(.automatic)
        )
        guard let unit else { return number }
        return number + unit
    }

    private static func magnitudeText(_ money: Money) -> String {
        money.amount.formatted(
            .number
                .precision(.fractionLength(fractionDigits(for: money.currency)))
                .grouping(.automatic)
        )
    }

    private static func symbol(for currency: Currency) -> String {
        switch currency {
        case .krw: "₩"
        case .usd: "$"
        }
    }

    private static func fractionDigits(for currency: Currency) -> Int {
        switch currency {
        case .krw: 0
        case .usd: 2
        }
    }
}

fileprivate enum Constants {
    /// 코인 수량이 잘리지 않을 만큼만 남긴다.
    static let maximumQuantityFractionDigits = 8
}
