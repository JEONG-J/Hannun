//
//  ExchangeRateTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import Testing
@testable import HannunCore

@Suite("ExchangeRate")
struct ExchangeRateTests {
    private let rate = ExchangeRate(krwPerUSD: 1_300)

    @Test("같은 통화면 값을 그대로 돌려준다")
    func keepsSameCurrency() {
        #expect(rate.convert(.krw(10_000), to: .krw) == .krw(10_000))
        #expect(rate.convert(.usd(100), to: .usd) == .usd(100))
    }

    @Test("달러를 원으로 환산한다")
    func convertsToKRW() {
        #expect(rate.convert(.usd(100), to: .krw) == .krw(130_000))
    }

    @Test("원을 달러로 환산한다")
    func convertsToUSD() {
        #expect(rate.convert(.krw(130_000), to: .usd) == .usd(100))
    }

    @Test("왕복 환산은 원래 금액으로 돌아온다")
    func roundTripsWithoutDrift() {
        let converted = rate.convert(.usd(1_234), to: .krw)

        #expect(rate.convert(converted, to: .usd) == .usd(1_234))
    }

    @Test("환율이 0 이하면 0 으로 막는다", arguments: [Decimal(0), Decimal(-1_300)])
    func rejectsNonPositiveRate(krwPerUSD: Decimal) {
        let broken = ExchangeRate(krwPerUSD: krwPerUSD)

        #expect(broken.convert(.usd(100), to: .krw) == .krw(0))
        #expect(broken.convert(.krw(130_000), to: .usd) == .usd(0))
    }
}
