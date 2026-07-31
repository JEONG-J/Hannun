//
//  ReturnRate.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 수익률 비율(`0.094`)을 화면 값으로 바꾸는 한 곳.
///
/// `AmountFormatter.percentage(ratio:)` 와 같은 규칙(부호 + 소수 2자리)이지만 그쪽은
/// `HannunDesignSystem` 내부 타입이라 Feature 에서 부를 수 없다. 규칙이 갈리지 않도록
/// 자릿수·부호 처리를 이 한 곳에만 둔다.
enum ReturnRate {

    /// `0.094` → `+9.40%`.
    static func text(_ rate: Decimal) -> String {
        let magnitude = rate.magnitude.formatted(
            .percent.precision(.fractionLength(Constants.fractionDigits))
        )
        return sign(of: rate) + magnitude
    }

    /// `0.094` → `9.4`. 차트 축이 % 정규화라 플롯 값도 백분율 스케일로 맞춘다.
    static func plotValue(_ rate: Decimal) -> Double {
        NSDecimalNumber(decimal: rate * Constants.percentScale).doubleValue
    }

    private static func sign(of rate: Decimal) -> String {
        if rate < 0 {
            Constants.negativeSign
        } else if rate > 0 {
            Constants.positiveSign
        } else {
            ""
        }
    }
}

fileprivate enum Constants {
    static let fractionDigits = 2
    static let percentScale: Decimal = 100
    static let positiveSign = "+"
    static let negativeSign = "-"
}
