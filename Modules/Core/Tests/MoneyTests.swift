//
//  MoneyTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
@testable import HannunCore

@Suite("Money")
struct MoneyTests {
    @Test("팩토리 메서드가 통화를 올바르게 설정한다")
    func factorySetsCurrency() {
        #expect(Money.krw(1_000).currency == .krw)
        #expect(Money.usd(10).currency == .usd)
    }

    @Test("통화가 다르면 같은 금액이라도 동등하지 않다")
    func differentCurrencyIsNotEqual() {
        #expect(Money.krw(10) != Money.usd(10))
    }
}
