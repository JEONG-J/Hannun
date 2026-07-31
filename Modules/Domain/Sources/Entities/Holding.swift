//
//  Holding.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import SwiftData

/// 보유 자산 1건.
///
/// CloudKit 동기화 스키마 제약을 만족시키려고 모든 프로퍼티에 기본값을 두고 유니크 제약을 쓰지 않는다.
/// "종목명은 필수" 같은 규칙은 모델이 아니라 `SaveHoldingUseCase` 가 검증한다.
@Model
public final class Holding {
    // MARK: - Property

    public var id: UUID = UUID()

    /// 열거형이 아니라 원시 문자열로 저장한다 — `#Predicate` 가 번역할 수 있는 형태여야
    /// 카테고리 필터를 메모리가 아니라 저장소에서 처리할 수 있다.
    public var categoryRawValue: String = AssetCategory.cash.rawValue

    public var name: String = ""
    public var ticker: String = ""
    public var currencyRawValue: String = Currency.krw.rawValue
    public var quantity: Decimal = 0

    /// 현금은 평단가가 없다.
    public var averagePrice: Decimal?

    /// 시세를 조회할 수 없는 종목에 사용자가 직접 넣은 현재가.
    public var manualPrice: Decimal?

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    /// 매매일지 태그의 반대편. CloudKit 은 양방향·optional 관계만 허용한다.
    public var journalEntries: [JournalEntry]?

    /// 모듈 경계를 넘길 수 있는 값 타입 표현.
    public var record: HoldingRecord {
        HoldingRecord(
            id: id,
            category: AssetCategory(rawValue: categoryRawValue) ?? .cash,
            name: name,
            ticker: ticker,
            currency: Currency(rawValue: currencyRawValue) ?? .krw,
            quantity: quantity,
            averagePrice: averagePrice,
            manualPrice: manualPrice,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Function

    public init(record: HoldingRecord) {
        id = record.id
        categoryRawValue = record.category.rawValue
        name = record.name
        ticker = record.ticker
        currencyRawValue = record.currency.rawValue
        quantity = record.quantity
        averagePrice = record.averagePrice
        manualPrice = record.manualPrice
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    /// 식별자와 생성 시각은 그대로 두고 나머지를 덮어쓴다.
    public func apply(_ record: HoldingRecord) {
        categoryRawValue = record.category.rawValue
        name = record.name
        ticker = record.ticker
        currencyRawValue = record.currency.rawValue
        quantity = record.quantity
        averagePrice = record.averagePrice
        manualPrice = record.manualPrice
        updatedAt = record.updatedAt
    }
}

/// `Holding` 의 값 타입 표현.
///
/// `@Model` 클래스는 `Sendable` 이 아니라 Repository 경계를 넘지 못한다.
/// 경계에서 이 타입으로 바꿔 넘기는 것이 Domain↔Data 분리를 지키는 실질적 장치다.
public struct HoldingRecord: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let id: UUID
    public var category: AssetCategory
    public var name: String
    public var ticker: String
    public var currency: Currency
    public var quantity: Decimal
    public var averagePrice: Decimal?
    public var manualPrice: Decimal?
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        category: AssetCategory,
        name: String,
        ticker: String = "",
        currency: Currency = .krw,
        quantity: Decimal,
        averagePrice: Decimal? = nil,
        manualPrice: Decimal? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.ticker = ticker
        self.currency = currency
        self.quantity = quantity
        self.averagePrice = averagePrice
        self.manualPrice = manualPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
