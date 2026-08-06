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

    /// 앱을 켜지 않아 직전 값을 옮겨 적은 날이면 `true`.
    ///
    /// 기본값이 `false` 라 이 속성이 생기기 전에 저장된 기록은 전부 실측으로 남는다 —
    /// 출처를 되살릴 방법이 없어 소급 재계산은 하지 않는다.
    public var isCarriedForward: Bool = false

    public var record: NetWorthRecord {
        NetWorthRecord(
            id: id,
            recordedOn: recordedOn,
            totalInKRW: .krw(totalInKRW),
            totalInUSD: .usd(totalInUSD),
            categorySubtotals: categorySubtotals,
            isCarriedForward: isCarriedForward
        )
    }

    // MARK: - Function

    public init(record: NetWorthRecord) {
        id = record.id
        recordedOn = record.recordedOn
        totalInKRW = record.totalInKRW.amount
        totalInUSD = record.totalInUSD.amount
        categorySubtotals = record.categorySubtotals
        isCarriedForward = record.isCarriedForward
    }

    public func apply(_ record: NetWorthRecord) {
        recordedOn = record.recordedOn
        totalInKRW = record.totalInKRW.amount
        totalInUSD = record.totalInUSD.amount
        categorySubtotals = record.categorySubtotals
        isCarriedForward = record.isCarriedForward
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

    /// 실측이 아니라 직전 값을 그대로 옮겨 적은 날인지.
    ///
    /// 추이선은 이 날도 함께 그리지만, **전일 대비 차분인 일간 수익률은 여기서 반드시 `0`**
    /// 이 나온다 — 시세를 못 받은 날과 정말로 안 움직인 날이 같은 값이 되므로 파생 쪽에서
    /// 이 표식을 보고 갈라야 한다.
    public var isCarriedForward: Bool

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        recordedOn: Date,
        totalInKRW: Money,
        totalInUSD: Money,
        categorySubtotals: [CategorySubtotal] = [],
        isCarriedForward: Bool = false
    ) {
        self.id = id
        self.recordedOn = recordedOn
        self.totalInKRW = totalInKRW
        self.totalInUSD = totalInUSD
        self.categorySubtotals = categorySubtotals
        self.isCarriedForward = isCarriedForward
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
            categorySubtotals: categorySubtotals,
            isCarriedForward: true
        )
    }
}
