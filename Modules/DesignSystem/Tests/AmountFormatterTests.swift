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

    /// 0 은 등락이 아니라 **기준선**이다. `+0%` 로 찍으면 오른 것처럼 읽힌다.
    @Test("Y축 0 눈금에는 부호를 붙이지 않는다")
    func axisBaselineLabelHasNoSign() {
        #expect(AmountFormatter.percentAxisLabel(plotValue: 0) == "0%")
        #expect(AmountFormatter.percentAxisLabel(plotValue: 5) == "+5%")
        #expect(AmountFormatter.percentAxisLabel(plotValue: -5) == "-5%")
    }

    /// 진폭이 1% 도 안 되는 구간에서는 눈금이 전부 `0%` 로 뭉개지므로 정수로 자르지 않는다.
    /// 반대로 정수 눈금에 `.0` 이 붙으면 축이 시끄러워진다 — 필요한 자리만 남긴다.
    @Test("Y축 눈금은 소수 한 자리까지만 남긴다")
    func axisLabelKeepsOneFractionDigitAtMost() {
        #expect(AmountFormatter.percentAxisLabel(plotValue: 9.4) == "+9.4%")
        #expect(AmountFormatter.percentAxisLabel(plotValue: 0.5) == "+0.5%")
        #expect(AmountFormatter.percentAxisLabel(plotValue: 12.34) == "+12.3%")
        #expect(AmountFormatter.percentAxisLabel(plotValue: 10) == "+10%")
    }

    /// 축 값은 `percentPlotValue(ratio:)` 가 옮긴 눈금 위에 있다 — 둘이 다른 배율을 쓰면
    /// 라벨이 실제 선 위치와 어긋난다.
    @Test("Y축 라벨은 플롯 값과 같은 눈금을 읽는다")
    func axisLabelReadsPlotScale() {
        let plotValue = AmountFormatter.percentPlotValue(ratio: 0.094)

        #expect(AmountFormatter.percentAxisLabel(plotValue: plotValue) == "+9.4%")
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

    // MARK: - narrow

    /// `compact` 는 `₩12억 3,457만` 처럼 두 단위를 이어 붙여 열한 자까지 자란다.
    /// 홀은 그 길이를 못 받으므로 `narrow` 는 큰 단위 하나에서 끊는다.
    @Test("좁은 자리 표기는 단위를 하나만 쓴다")
    func narrowFoldsIntoSingleUnit() {
        #expect(AmountFormatter.compact(.krw(1_234_567_890)) == "₩12억 3,457만")
        #expect(AmountFormatter.narrow(.krw(1_234_567_890)) == "₩12.35억")
    }

    @Test("원화는 100만부터 접는다 — 그 아래는 여덟 자로 이미 들어간다")
    func narrowKrwFoldsFromMillion() {
        #expect(AmountFormatter.narrow(.krw(999_999)) == "₩999,999")
        #expect(AmountFormatter.narrow(.krw(1_000_000)) == "₩100만")
        #expect(AmountFormatter.narrow(.krw(1_234_567)) == "₩123.5만")
    }

    /// `compact` 가 1,000만 미만을 손대지 않아 `₩9,876,543` 을 열 자로 내보내는 구간이다.
    /// 홀은 이 구간에서도 접혀야 한다.
    @Test("compact 가 접지 않는 백만 원대도 narrow 는 접는다")
    func narrowCoversCompactGap() {
        #expect(AmountFormatter.compact(.krw(9_876_543)) == "₩9,876,543")
        #expect(AmountFormatter.narrow(.krw(9_876_543)) == "₩987.7만")
    }

    @Test("유효숫자는 어느 구간에서도 네 자리로 남는다")
    func narrowKeepsFourSignificantDigits() {
        #expect(AmountFormatter.narrow(.krw(13_371_000)) == "₩1,337만")
        #expect(AmountFormatter.narrow(.krw(134_371_000)) == "₩1.344억")
        #expect(AmountFormatter.narrow(.krw(12_345_678_900)) == "₩123.5억")
        #expect(AmountFormatter.narrow(.krw(123_456_789_000)) == "₩1,235억")
    }

    /// 네 자리로 반올림하다 단위 경계를 넘으면 `₩10,000만` 이 되어 자릿수가 하나 늘어난다.
    @Test("만 단위가 반올림으로 넘치면 억으로 올라간다")
    func narrowPromotesRoundedUnit() {
        #expect(AmountFormatter.narrow(.krw(99_996_000)) == "₩1억")
        #expect(AmountFormatter.narrow(.krw(99_994_000)) == "₩9,999만")
    }

    @Test("뒤따르는 0 은 자리만 먹으므로 지운다")
    func narrowTrimsTrailingZeros() {
        #expect(AmountFormatter.narrow(.krw(2_000_000)) == "₩200만")
        #expect(AmountFormatter.narrow(.krw(300_000_000)) == "₩3억")
    }

    @Test("달러는 1,000부터 접는다")
    func narrowUsdFoldsFromThousand() {
        #expect(AmountFormatter.narrow(.usd(999.99)) == "$999.99")
        #expect(AmountFormatter.narrow(.usd(96_412.50)) == "$96.41K")
        #expect(AmountFormatter.narrow(.usd(1_234_567.89)) == "$1.235M")
    }

    @Test("부호는 전체 표기와 같은 자리 — 통화기호 앞이다")
    func narrowKeepsSignPlacement() {
        #expect(AmountFormatter.narrow(.krw(-13_371_000)) == "-₩1,337만")
        #expect(AmountFormatter.narrow(.krw(13_371_000), showsPositiveSign: true) == "+₩1,337만")
        #expect(AmountFormatter.narrow(.krw(0)) == "₩0")
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
