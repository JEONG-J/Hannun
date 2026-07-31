//
//  AmountFormatter.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 금액·수익률 문자열을 만드는 단일 창구.
///
/// `AmountText` 와 `ChangePill` 이 같은 규칙(자릿수·부호·통화기호)을 공유하게 한 곳에 묶는다.
/// 두 컴포넌트가 각자 포맷팅하면 같은 값이 화면마다 다르게 찍힌다.
enum AmountFormatter {

    /// 금액을 위계별로 쪼갠 결과. 통화기호와 소수부는 한 단계 죽여 그리므로 따로 돌려준다.
    struct Parts: Equatable {
        let sign: String
        let symbol: String
        let integer: String
        /// 소수 구분자를 포함한다. 소수부가 없으면 빈 문자열.
        let fraction: String

        var text: String { sign + symbol + integer + fraction }
    }

    static func parts(for money: Money, showsPositiveSign: Bool = false) -> Parts {
        let magnitude = money.amount.magnitude
        let formatted = magnitude.formatted(
            .number.precision(.fractionLength(money.currency.fractionDigits)).grouping(.automatic)
        )
        let separator = Locale.current.decimalSeparator ?? Constants.fallbackDecimalSeparator
        let sign = sign(of: money.amount, showsPositiveSign: showsPositiveSign)

        guard let separatorRange = formatted.range(of: separator) else {
            return Parts(
                sign: sign,
                symbol: money.currency.symbol,
                integer: formatted,
                fraction: ""
            )
        }

        return Parts(
            sign: sign,
            symbol: money.currency.symbol,
            integer: String(formatted[..<separatorRange.lowerBound]),
            fraction: String(formatted[separatorRange.lowerBound...])
        )
    }

    static func text(for money: Money, showsPositiveSign: Bool = false) -> String {
        parts(for: money, showsPositiveSign: showsPositiveSign).text
    }

    /// - Parameter ratio: 백분율이 아니라 **비율**을 넣는다 — `0.0098` 이 `+0.98%` 가 된다.
    static func percentage(ratio: Decimal, showsPositiveSign: Bool = true) -> String {
        let magnitude = ratio.magnitude.formatted(
            .percent.precision(.fractionLength(Constants.percentFractionDigits))
        )
        return sign(of: ratio, showsPositiveSign: showsPositiveSign) + magnitude
    }

    private static func sign(of value: Decimal, showsPositiveSign: Bool) -> String {
        if value < 0 {
            Constants.negativeSign
        } else if showsPositiveSign, value > 0 {
            Constants.positiveSign
        } else {
            ""
        }
    }
}

extension Currency {
    var symbol: String {
        switch self {
        case .krw: "₩"
        case .usd: "$"
        }
    }

    /// 원화는 소수부를 쓰지 않는다. 달러만 센트 단위까지 보여준다.
    var fractionDigits: Int {
        switch self {
        case .krw: 0
        case .usd: 2
        }
    }
}

fileprivate enum Constants {
    static let percentFractionDigits = 2
    static let fallbackDecimalSeparator = "."
    static let positiveSign = "+"
    static let negativeSign = "-"
}
