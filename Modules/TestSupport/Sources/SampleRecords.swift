//
//  SampleRecords.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// 테스트가 공유하는 고정 픽스처.
///
/// 날짜는 `Date()` 대신 이 헬퍼로 만들어야 실행 시점과 무관하게 결과가 같다.
public enum SampleRecords {
    // MARK: - Function

    /// 그레고리력 자정 기준 날짜. 시간대 차이로 하루가 밀리지 않도록 UTC 로 고정한다.
    public static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// `day(_:_:_:)` 와 짝을 이루는 달력. UseCase 에 주입해 시간대 의존을 없앤다.
    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    public static func holding(
        id: UUID = UUID(),
        category: AssetCategory,
        name: String,
        ticker: String = "",
        currency: Currency = .krw,
        quantity: Decimal,
        averagePrice: Decimal? = nil,
        manualPrice: Decimal? = nil,
        createdAt: Date = day(2026, 1, 1)
    ) -> HoldingRecord {
        HoldingRecord(
            id: id,
            category: category,
            name: name,
            ticker: ticker,
            currency: currency,
            quantity: quantity,
            averagePrice: averagePrice,
            manualPrice: manualPrice,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    public static func cashFlow(
        id: UUID = UUID(),
        occurredOn: Date,
        amount: Decimal,
        currency: Currency = .krw,
        kind: CashFlowKind,
        memo: String = ""
    ) -> CashFlowRecord {
        CashFlowRecord(
            id: id,
            occurredOn: occurredOn,
            amount: amount,
            currency: currency,
            kind: kind,
            memo: memo
        )
    }

    public static func snapshot(
        id: UUID = UUID(),
        recordedOn: Date,
        totalInKRW: Decimal,
        totalInUSD: Decimal = 0,
        categorySubtotals: [CategorySubtotal] = [],
        isCarriedForward: Bool = false
    ) -> NetWorthRecord {
        NetWorthRecord(
            id: id,
            recordedOn: recordedOn,
            totalInKRW: .krw(totalInKRW),
            totalInUSD: .usd(totalInUSD),
            categorySubtotals: categorySubtotals,
            isCarriedForward: isCarriedForward
        )
    }

    public static func benchmark(
        id: UUID = UUID(),
        recordedOn: Date,
        index: BenchmarkIndex,
        value: Decimal
    ) -> BenchmarkRecord {
        BenchmarkRecord(id: id, recordedOn: recordedOn, index: index, value: value)
    }

    public static func journal(
        id: UUID = UUID(),
        writtenAt: Date,
        title: String,
        content: String = "",
        holdingIDs: [UUID] = []
    ) -> JournalRecord {
        JournalRecord(
            id: id,
            writtenAt: writtenAt,
            title: title,
            content: content,
            holdingIDs: holdingIDs,
            updatedAt: writtenAt
        )
    }
}
