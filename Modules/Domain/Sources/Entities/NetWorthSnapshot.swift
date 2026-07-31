//
//  NetWorthSnapshot.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import SwiftData

/// 스냅샷 시점의 카테고리 소계 한 줄. 금액 기준 통화는 KRW 다.
public struct CategorySubtotal: Codable, Hashable, Sendable {
    public let category: AssetCategory
    public let amount: Decimal

    public init(category: AssetCategory, amount: Decimal) {
        self.category = category
        self.amount = amount
    }
}

/// 하루 단위로 남기는 총자산 기록.
///
/// 월별 추이는 별도 엔티티가 아니라 이 일별 기록에서 각 달의 첫 스냅샷을 골라 만든다 —
/// 같은 날짜가 두 벌 쌓이는 것을 피하려는 선택이다.
@Model
public final class NetWorthSnapshot {
    // MARK: - Property

    public var id: UUID = UUID()

    /// 자정으로 정규화한 기록 일자. 하루에 한 건이 스냅샷의 단위다.
    public var recordedOn: Date = Date()

    public var totalInKRW: Decimal = 0
    public var totalInUSD: Decimal = 0

    /// Codable 배열이라 SwiftData 가 단일 속성으로 저장한다 — CloudKit 이 다루지 못하는
    /// 딕셔너리·정렬 관계를 쓰지 않으려는 형태다.
    public var categorySubtotals: [CategorySubtotal] = []

    public var record: NetWorthRecord {
        NetWorthRecord(
            id: id,
            recordedOn: recordedOn,
            totalInKRW: .krw(totalInKRW),
            totalInUSD: .usd(totalInUSD),
            categorySubtotals: categorySubtotals
        )
    }

    // MARK: - Function

    public init(record: NetWorthRecord) {
        id = record.id
        recordedOn = record.recordedOn
        totalInKRW = record.totalInKRW.amount
        totalInUSD = record.totalInUSD.amount
        categorySubtotals = record.categorySubtotals
    }

    public func apply(_ record: NetWorthRecord) {
        recordedOn = record.recordedOn
        totalInKRW = record.totalInKRW.amount
        totalInUSD = record.totalInUSD.amount
        categorySubtotals = record.categorySubtotals
    }
}

/// `NetWorthSnapshot` 의 값 타입 표현.
public struct NetWorthRecord: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let id: UUID
    public var recordedOn: Date
    public var totalInKRW: Money
    public var totalInUSD: Money
    public var categorySubtotals: [CategorySubtotal]

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        recordedOn: Date,
        totalInKRW: Money,
        totalInUSD: Money,
        categorySubtotals: [CategorySubtotal] = []
    ) {
        self.id = id
        self.recordedOn = recordedOn
        self.totalInKRW = totalInKRW
        self.totalInUSD = totalInUSD
        self.categorySubtotals = categorySubtotals
    }

    public func total(in currency: Currency) -> Money {
        switch currency {
        case .krw: totalInKRW
        case .usd: totalInUSD
        }
    }

    /// 날짜만 옮긴 사본. 앱을 실행하지 않아 비어 있는 날을 직전 값으로 채울 때 쓴다.
    public func carriedForward(to date: Date) -> NetWorthRecord {
        NetWorthRecord(
            recordedOn: date,
            totalInKRW: totalInKRW,
            totalInUSD: totalInUSD,
            categorySubtotals: categorySubtotals
        )
    }
}
