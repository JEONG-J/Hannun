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

    /// 폭이 없는 자리(액세서리 한 줄)에 넣는 축약 금액 — `₩1억 2,340만` · `$1.23M`.
    ///
    /// 자릿수를 지우는 대신 **단위를 올린다**. 전체 금액은 화면 본문의 히어로가 이미 정확히
    /// 보여주고 있으므로, 여기서는 "얼마쯤인지"만 한눈에 들어오면 된다. 어느 구간에서도
    /// 유효숫자 네 자리는 남겨 두 값의 대소가 뒤집히지 않게 한다.
    public static func compact(_ money: Money, showsPositiveSign: Bool = false) -> String {
        let sign = sign(of: money.amount, showsPositiveSign: showsPositiveSign)
        let magnitude = money.amount.magnitude
        let body = switch money.currency {
        case .krw: compactKrw(magnitude)
        case .usd: compactUsd(magnitude)
        }
        return sign + money.currency.symbol + body
    }

    /// 한 줄이 아니라 한 낱말 폭밖에 없는 자리(도넛 중앙 홀)에 넣는 축약 금액 —
    /// `₩123.5만` · `₩12.35억` · `$1.235M`.
    ///
    /// `compact(_:)` 와 갈리는 지점은 **단위를 하나만 쓴다**는 것이다. `₩12억 3,457만` 은
    /// 열한 자여서 지름 124pt 홀에 못 들어간다. 큰 단위 하나에 소수를 붙이면 유효숫자 네 자리를
    /// 그대로 지키면서 여덟 자를 넘지 않는다.
    ///
    /// 접기 시작하는 경계도 `compact(_:)` 보다 한 단계 이르다 — 원화는 100만, 달러는 1,000
    /// 부터다. 그 아래는 자릿수를 다 적어도 여덟 자를 넘지 않아 접을 이유가 없다.
    ///
    /// 단위는 억(달러는 M)에서 멈춘다. 여덟 자 보장이 깨지는 건 원화 10조·달러 1,000억부터인데
    /// 개인 자산 앱의 사정권 밖이라 조 단위를 새로 들이지 않는다.
    public static func narrow(_ money: Money, showsPositiveSign: Bool = false) -> String {
        let sign = sign(of: money.amount, showsPositiveSign: showsPositiveSign)
        let magnitude = money.amount.magnitude
        let body = switch money.currency {
        case .krw: narrowKrw(magnitude)
        case .usd: narrowUsd(magnitude)
        }
        return sign + money.currency.symbol + body
    }

    /// 축약 수익률 — `+12.4%`. 소수 두 자리는 캡션 폭에서 값보다 노이즈가 크다.
    public static func compactPercentage(ratio: Decimal, showsPositiveSign: Bool = true) -> String {
        let magnitude = ratio.magnitude.formatted(
            .percent.precision(.fractionLength(Constants.compactPercentFractionDigits))
        )
        return sign(of: ratio, showsPositiveSign: showsPositiveSign) + magnitude
    }

    /// 벤치마크 대비 초과수익 — `+1.4%p`.
    ///
    /// 단위가 `%` 가 아니라 `%p` 인 것이 핵심이다. 두 수익률의 **차이**는 비율이 아니라
    /// 백분율 포인트이며, `%` 로 적으면 "내 수익률의 1.4%" 로 읽혀 뜻이 달라진다.
    public static func percentagePoint(
        ratioDifference: Decimal,
        showsPositiveSign: Bool = true
    ) -> String {
        let magnitude = (ratioDifference.magnitude * Constants.percentScale).formatted(
            .number.precision(.fractionLength(Constants.compactPercentFractionDigits))
        )
        let sign = sign(of: ratioDifference, showsPositiveSign: showsPositiveSign)
        return sign + magnitude + Constants.percentagePointUnit
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

    /// 차트 축에 올릴 금액. `percentPlotValue(ratio:)` 의 금액 갈래이며 배율을 두지 않는다 —
    /// 축 값이 곧 원 단위 금액이라 `currencyAxisLabel(plotValue:)` 이 그대로 되읽는다.
    public static func currencyPlotValue(_ money: Money) -> Double {
        NSDecimalNumber(decimal: money.amount).doubleValue
    }

    /// 차트 Y축 눈금 라벨 — `+9%` · `0%` · `-3%`.
    ///
    /// `percentPlotValue(ratio:)` 가 옮겨 놓은 백분율 눈금을 그대로 받는다. 축은 라벨을 놓을
    /// 폭이 좁아 소수부를 한 자리로 자르되, 진폭이 1% 도 안 되는 구간에서는 눈금이 전부
    /// `0%` 로 뭉개지므로 정수로 고정하지는 않는다.
    ///
    /// 0 에는 부호를 붙이지 않는다 — 0% 는 등락이 아니라 **기준선**이고, `+0%` 는 오른 것처럼
    /// 읽힌다.
    public static func percentAxisLabel(plotValue: Double) -> String {
        let rounded = (plotValue * Constants.axisRoundingScale).rounded()
            / Constants.axisRoundingScale
        let magnitude = abs(rounded).formatted(
            .number.precision(.fractionLength(0...Constants.compactPercentFractionDigits))
        )
        let sign = sign(of: Decimal(rounded), showsPositiveSign: true)
        return sign + magnitude + Constants.percentUnit
    }

    /// 차트 Y축 눈금 라벨의 금액 갈래 — `₩1.234억` · `₩5,234만`.
    ///
    /// 통화를 원화로 못 박는다. 축 값은 통화를 잃은 `Double` 이고, 이 라벨을 쓰는 추이 차트는
    /// 기준통화(원화)로 환산된 총자산만 그린다 — 다른 통화가 들어올 자리가 없다.
    ///
    /// 접는 규칙은 `narrow(_:)` 를 그대로 빌린다. 240pt 플롯의 축 라벨 두 개는 도넛 홀과 같은
    /// 폭 제약을 받으므로 두 단위를 이어 붙이는 `compact(_:)` 는 들어가지 않는다.
    public static func currencyAxisLabel(plotValue: Double) -> String {
        narrow(.krw(Decimal(plotValue)))
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

    /// 억 아래로 내려가도 만 단위로 접는 건 천만 원부터다. 12,345 원을 "1만" 으로 적으면
    /// 유효숫자가 한 자리만 남아 옆 값과 비교가 안 된다.
    private static func compactKrw(_ magnitude: Decimal) -> String {
        if magnitude >= Constants.hundredMillion {
            var eok = rounded(magnitude / Constants.hundredMillion, scale: 0, mode: .down)
            var man = rounded(
                (magnitude - eok * Constants.hundredMillion) / Constants.tenThousand,
                scale: 0,
                mode: .plain
            )
            // 9,999.6만 이 10,000만 으로 올림되면 억으로 올려 보낸다.
            if man >= Constants.tenThousand {
                eok += 1
                man = 0
            }
            guard man > 0 else { return integerString(eok) + Constants.hundredMillionUnit }
            return integerString(eok) + Constants.hundredMillionUnit + " "
                + integerString(man) + Constants.tenThousandUnit
        }

        if magnitude >= Constants.tenMillion {
            let man = rounded(magnitude / Constants.tenThousand, scale: 0, mode: .plain)
            return integerString(man) + Constants.tenThousandUnit
        }

        return integerString(rounded(magnitude, scale: 0, mode: .plain))
    }

    private static func compactUsd(_ magnitude: Decimal) -> String {
        if magnitude >= Constants.million {
            return decimalString(magnitude / Constants.million, fractionDigits: 2)
                + Constants.millionUnit
        }

        if magnitude >= Constants.tenThousand {
            return decimalString(magnitude / Constants.thousand, fractionDigits: 1)
                + Constants.thousandUnit
        }

        return decimalString(magnitude, fractionDigits: Currency.usd.fractionDigits)
    }

    /// 100만부터 만, 1억부터 억. `compact` 가 1,000만에서 접기 시작하는 것보다 한 단계 이른데,
    /// 여기서는 유효숫자가 아니라 **폭**이 경계를 정하기 때문이다 — `₩1,000,000` 은 열 자라
    /// 이미 홀을 넘고 `₩999,999` 는 여덟 자로 들어간다.
    private static func narrowKrw(_ magnitude: Decimal) -> String {
        guard magnitude >= Constants.million else {
            return integerString(rounded(magnitude, scale: 0, mode: .plain))
        }

        // 9,999.6만 이 네 자리로 반올림되며 10,000만 이 되면 만으로 적을 수 없다 — 억으로 넘긴다.
        let tenThousands = magnitude / Constants.tenThousand
        guard magnitude < Constants.hundredMillion,
              rounded(tenThousands, scale: 0, mode: .plain) < Constants.tenThousand else {
            return significantString(magnitude / Constants.hundredMillion)
                + Constants.hundredMillionUnit
        }

        return significantString(tenThousands) + Constants.tenThousandUnit
    }

    private static func narrowUsd(_ magnitude: Decimal) -> String {
        guard magnitude >= Constants.thousand else {
            return decimalString(magnitude, fractionDigits: Currency.usd.fractionDigits)
        }

        let thousands = magnitude / Constants.thousand
        guard magnitude < Constants.million,
              rounded(thousands, scale: 0, mode: .plain) < Constants.thousand else {
            return significantString(magnitude / Constants.million) + Constants.millionUnit
        }

        return significantString(thousands) + Constants.thousandUnit
    }

    /// 유효숫자를 네 자리로 맞춘다 — `1.235` · `12.35` · `123.5` · `1,235`.
    /// 뒤따르는 0 은 지운다. `₩100.0만` 의 마지막 자리는 정보가 아니라 자리만 먹는다.
    private static func significantString(_ value: Decimal) -> String {
        let fractionDigits = if value >= Constants.thousand {
            0
        } else if value >= Constants.hundred {
            1
        } else if value >= Constants.ten {
            2
        } else {
            Constants.narrowSignificantDigits - 1
        }

        return value.formatted(
            .number.precision(.fractionLength(0...fractionDigits)).grouping(.automatic)
        )
    }

    private static func integerString(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0)).grouping(.automatic))
    }

    private static func decimalString(_ value: Decimal, fractionDigits: Int) -> String {
        value.formatted(
            .number.precision(.fractionLength(fractionDigits)).grouping(.automatic)
        )
    }

    private static func rounded(
        _ value: Decimal,
        scale: Int,
        mode: NSDecimalNumber.RoundingMode
    ) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
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

    /// VoiceOver 가 읽을 이름. 코드(`USD`)는 눈으로 볼 때만 짧아서 좋고 귀로 들으면 철자다.
    var displayName: String {
        switch self {
        case .krw: "원화"
        case .usd: "미국 달러"
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
    /// 캡션 폭에서는 소수 한 자리까지가 정보, 그 아래는 노이즈다.
    static let compactPercentFractionDigits = 1
    static let percentScale: Decimal = 100
    /// 축 라벨을 소수 한 자리에서 끊기 위한 반올림 배율.
    static let axisRoundingScale: Double = 10
    static let percentUnit = "%"
    static let percentagePointUnit = "%p"
    static let hundredMillion: Decimal = 100_000_000
    static let tenMillion: Decimal = 10_000_000
    static let tenThousand: Decimal = 10_000
    static let million: Decimal = 1_000_000
    static let thousand: Decimal = 1_000
    static let hundred: Decimal = 100
    static let ten: Decimal = 10
    /// 단위 하나로 접어도 두 값의 대소가 뒤집히지 않게 남기는 자릿수. `compact` 와 같은 약속이다.
    static let narrowSignificantDigits = 4
    static let hundredMillionUnit = "억"
    static let tenThousandUnit = "만"
    static let millionUnit = "M"
    static let thousandUnit = "K"
    /// 코인 수량이 잘리지 않을 만큼만 남긴다.
    static let maximumQuantityFractionDigits = 8
    static let fallbackDecimalSeparator = "."
    static let positiveSign = "+"
    static let negativeSign = "-"
}
