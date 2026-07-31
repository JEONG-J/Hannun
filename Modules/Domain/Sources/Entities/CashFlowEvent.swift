//
//  CashFlowEvent.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import SwiftData

/// 입출금 구분.
public enum CashFlowKind: String, Codable, Sendable, CaseIterable {
    case deposit
    case withdrawal
}

/// 성과(수익률) 계산에서 제외해야 하는 입출금 기록 1건.
@Model
public final class CashFlowEvent {
    // MARK: - Property

    public var id: UUID = UUID()
    public var occurredOn: Date = Date()
    public var amount: Decimal = 0
    public var currencyRawValue: String = Currency.krw.rawValue
    public var kindRawValue: String = CashFlowKind.deposit.rawValue
    public var memo: String = ""

    public var record: CashFlowRecord {
        CashFlowRecord(
            id: id,
            occurredOn: occurredOn,
            amount: amount,
            currency: Currency(rawValue: currencyRawValue) ?? .krw,
            kind: CashFlowKind(rawValue: kindRawValue) ?? .deposit,
            memo: memo
        )
    }

    // MARK: - Function

    public init(record: CashFlowRecord) {
        id = record.id
        occurredOn = record.occurredOn
        amount = record.amount
        currencyRawValue = record.currency.rawValue
        kindRawValue = record.kind.rawValue
        memo = record.memo
    }

    public func apply(_ record: CashFlowRecord) {
        occurredOn = record.occurredOn
        amount = record.amount
        currencyRawValue = record.currency.rawValue
        kindRawValue = record.kind.rawValue
        memo = record.memo
    }
}

/// `CashFlowEvent` 의 값 타입 표현.
public struct CashFlowRecord: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let id: UUID
    public var occurredOn: Date
    public var amount: Decimal
    public var currency: Currency
    public var kind: CashFlowKind
    public var memo: String

    /// 입금은 +, 출금은 −. YTD 계산의 순입출금이 이 부호를 그대로 더한다.
    public var signedAmount: Decimal {
        kind == .deposit ? amount : -amount
    }

    /// 부호까지 반영한 금액.
    public var signedMoney: Money {
        Money(amount: signedAmount, currency: currency)
    }

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        occurredOn: Date,
        amount: Decimal,
        currency: Currency = .krw,
        kind: CashFlowKind,
        memo: String = ""
    ) {
        self.id = id
        self.occurredOn = occurredOn
        self.amount = amount
        self.currency = currency
        self.kind = kind
        self.memo = memo
    }
}
