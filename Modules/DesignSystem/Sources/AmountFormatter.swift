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
/// 두 컴포넌트가 각자 포맷팅하면 같은 값이 화면마다 다르게 찍힌다. 컴포넌트를 거치지 않는
/// 보조 문구(행 서브라인·접근성 값)도 이 타입을 직접 부른다.
public enum AmountFormatter {

    /// 금액을 위계별로 쪼갠 결과. 통화기호와 소수부는 한 단계 죽여 그리므로 따로 돌려준다.
    public struct Parts: Equatable {
        public let sign: String
        public let symbol: String
        public let integer: String
        /// 소수 구분자를 포함한다. 소수부가 없으면 빈 문자열.
        public let fraction: String

        public var text: String { sign + symbol + integer + fraction }
    }

    /// 부호는 통화기호 **앞**에 붙는다 — `-₩1,000`. 회계 표기(`₩-1,000`)를 쓰지 않는 이유는
    /// `AmountText` 가 부호·기호·정수부를 서로 다른 크기로 그려서 부호가 기호 뒤로 가면
    /// 작은 글자 사이에 끼어 눈에 띄지 않기 때문이다.
    public static func parts(for money: Money, showsPositiveSign: Bool = false) -> Parts {
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

    public static func text(for money: Money, showsPositiveSign: Bool = false) -> String {
        parts(for: money, showsPositiveSign: showsPositiveSign).text
    }

    /// - Parameter ratio: 백분율이 아니라 **비율**을 넣는다 — `0.0098` 이 `+0.98%` 가 된다.
    public static func percentage(ratio: Decimal, showsPositiveSign: Bool = true) -> String {
        let magnitude = ratio.magnitude.formatted(
            .percent.precision(.fractionLength(Constants.percentFractionDigits))
        )
        return sign(of: ratio, showsPositiveSign: showsPositiveSign) + magnitude
    }

    /// 차트 축에 올릴 수익률. `percentage(ratio:)` 와 같은 비율을 받아 같은 백분율 눈금으로
    /// 옮긴다 — 축 값과 라벨 문구가 서로 다른 배율을 쓰지 않도록 여기서 함께 정한다.
    public static func percentPlotValue(ratio: Decimal) -> Double {
        NSDecimalNumber(decimal: ratio * Constants.percentScale).doubleValue
    }

    /// 소수 자릿수를 값에 맞춰 줄인다 — 10주는 `10`, 0.0521 BTC 는 `0.0521` 로 찍힌다.
    public static func quantity(_ value: Decimal, unit: String? = nil) -> String {
        let number = value.formatted(
            .number
                .precision(.fractionLength(0...Constants.maximumQuantityFractionDigits))
                .grouping(.automatic)
        )
        guard let unit else { return number }
        return number + unit
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

public extension Currency {
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
    static let percentScale: Decimal = 100
    /// 코인 수량이 잘리지 않을 만큼만 남긴다.
    static let maximumQuantityFractionDigits = 8
    static let fallbackDecimalSeparator = "."
    static let positiveSign = "+"
    static let negativeSign = "-"
}
