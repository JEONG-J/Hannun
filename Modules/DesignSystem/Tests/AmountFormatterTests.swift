//
//  AmountFormatterTests.swift
//  HannunDesignSystemTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import Testing
@testable import HannunDesignSystem

@Suite("AmountFormatter")
struct AmountFormatterTests {

    @Test("원화는 소수부 없이, 달러는 센트까지 찍는다")
    func fractionDigitsFollowCurrency() {
        #expect(AmountFormatter.text(for: .krw(1_240_000)) == "₩1,240,000")
        #expect(AmountFormatter.text(for: .usd(1_204.5)) == "$1,204.50")
    }

    /// 부호를 통화기호 뒤(`₩-1,000`)로 보내면 `AmountText` 가 한 단계 죽여 그리는 기호 옆에
    /// 붙어 눈에 띄지 않는다. 기호 앞이 이 앱의 규칙이다.
    @Test("음수 부호는 통화기호 앞에 온다")
    func negativeSignPrecedesCurrencySymbol() {
        #expect(AmountFormatter.text(for: .krw(-1_000)) == "-₩1,000")
    }

    @Test("양수 부호는 요청할 때만 붙는다")
    func positiveSignIsOptional() {
        #expect(AmountFormatter.text(for: .krw(1_000)) == "₩1,000")
        #expect(AmountFormatter.text(for: .krw(1_000), showsPositiveSign: true) == "+₩1,000")
        #expect(AmountFormatter.text(for: .krw(0), showsPositiveSign: true) == "₩0")
    }

    @Test("금액 조각은 합치면 완성 문구가 된다")
    func partsJoinIntoText() {
        let parts = AmountFormatter.parts(for: .usd(-1_204.35))

        #expect(parts.sign == "-")
        #expect(parts.symbol == "$")
        #expect(parts.integer == "1,204")
        #expect(parts.text == AmountFormatter.text(for: .usd(-1_204.35)))
    }

    @Test("수익률은 비율을 받아 백분율 두 자리로 찍는다")
    func percentageUsesRatio() {
        #expect(AmountFormatter.percentage(ratio: 0.0098) == "+0.98%")
        #expect(AmountFormatter.percentage(ratio: -0.0432) == "-4.32%")
        #expect(AmountFormatter.percentage(ratio: 0.0098, showsPositiveSign: false) == "0.98%")
    }

    /// `Decimal` 부동소수 리터럴은 `Double` 을 거쳐 들어와 끝자리가 흔들린다.
    /// 화면은 소수 2자리까지만 쓰므로 그 자리까지만 본다.
    @Test("플롯 값은 문구와 같은 백분율 눈금을 쓴다")
    func percentPlotValueMatchesPercentageScale() {
        #expect(abs(AmountFormatter.percentPlotValue(ratio: 0.094) - 9.4) < 0.0001)
        #expect(abs(AmountFormatter.percentPlotValue(ratio: -0.0312) + 3.12) < 0.0001)
        #expect(AmountFormatter.percentPlotValue(ratio: 0) == 0)
    }

    @Test("수량은 값에 맞춰 소수부를 줄인다")
    func quantityTrimsFractionDigits() {
        #expect(AmountFormatter.quantity(10) == "10")
        #expect(AmountFormatter.quantity(0.0521) == "0.0521")
        #expect(AmountFormatter.quantity(1_000) == "1,000")
    }

    @Test("수량 단위는 숫자 뒤에 그대로 붙는다")
    func quantityAppendsUnit() {
        #expect(AmountFormatter.quantity(10, unit: "주") == "10주")
        #expect(AmountFormatter.quantity(0.0521, unit: "개") == "0.0521개")
        #expect(AmountFormatter.quantity(10, unit: nil) == "10")
    }
}

@Suite("ChangePillContent")
struct ChangePillContentTests {

    @Test("손익 방향은 부호가 정한다")
    func directionFollowsSign() {
        #expect(ChangePillContent.ratio(0.01).direction == .gain)
        #expect(ChangePillContent.ratio(-0.01).direction == .loss)
        #expect(ChangePillContent.ratio(0).direction == .neutral)
        #expect(ChangePillContent.amount(.krw(-100)).direction == .loss)
    }

    /// 현재가처럼 오르내림이 아닌 값은 부호가 커도 손익색을 입히면 안 된다.
    @Test("중립 금액은 부호와 무관하게 중립이다")
    func neutralAmountIgnoresSign() {
        #expect(ChangePillContent.neutralAmount(.krw(69_100)).direction == .neutral)
        #expect(ChangePillContent.neutralAmount(.krw(-69_100)).direction == .neutral)
        #expect(ChangePillContent.neutralAmount(.krw(69_100)).text == "₩69,100")
    }

    @Test("금액·수익률 병기는 괄호로 묶는다")
    func amountWithRatioJoinsBothValues() {
        let content = ChangePillContent.amountWithRatio(.krw(1_240_000), 0.0098)

        #expect(content.text == "+₩1,240,000 (+0.98%)")
    }
}
