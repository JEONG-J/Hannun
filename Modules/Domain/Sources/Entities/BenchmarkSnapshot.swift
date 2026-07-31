//
//  BenchmarkSnapshot.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import SwiftData

/// 성과 탭이 내 수익률과 나란히 그리는 비교 지수.
public enum BenchmarkIndex: String, Codable, Sendable, CaseIterable {
    case kospi
    case sp500
    case nasdaq
    case bitcoin
}

/// 벤치마크 비교 차트를 그리려고 받아둔 지수 시세 1건.
@Model
public final class BenchmarkSnapshot {
    // MARK: - Property

    public var id: UUID = UUID()
    public var recordedOn: Date = Date()
    public var indexRawValue: String = BenchmarkIndex.kospi.rawValue
    public var value: Decimal = 0

    public var record: BenchmarkRecord {
        BenchmarkRecord(
            id: id,
            recordedOn: recordedOn,
            index: BenchmarkIndex(rawValue: indexRawValue) ?? .kospi,
            value: value
        )
    }

    // MARK: - Function

    public init(record: BenchmarkRecord) {
        id = record.id
        recordedOn = record.recordedOn
        indexRawValue = record.index.rawValue
        value = record.value
    }

    public func apply(_ record: BenchmarkRecord) {
        recordedOn = record.recordedOn
        indexRawValue = record.index.rawValue
        value = record.value
    }
}

/// `BenchmarkSnapshot` 의 값 타입 표현.
public struct BenchmarkRecord: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let id: UUID
    public var recordedOn: Date
    public var index: BenchmarkIndex
    public var value: Decimal

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        recordedOn: Date,
        index: BenchmarkIndex,
        value: Decimal
    ) {
        self.id = id
        self.recordedOn = recordedOn
        self.index = index
        self.value = value
    }
}
