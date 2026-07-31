//
//  Money.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation

/// 취급 통화. 해외 자산은 원화 환산 값을 함께 보관한다.
public enum Currency: String, Codable, Sendable, CaseIterable {
    case krw = "KRW"
    case usd = "USD"
}

/// 통화가 붙은 금액. 부동소수 오차를 피하려고 Decimal 을 쓴다.
public struct Money: Equatable, Sendable, Codable {
    public let amount: Decimal
    public let currency: Currency

    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    public static func krw(_ amount: Decimal) -> Money {
        Money(amount: amount, currency: .krw)
    }

    public static func usd(_ amount: Decimal) -> Money {
        Money(amount: amount, currency: .usd)
    }
}
