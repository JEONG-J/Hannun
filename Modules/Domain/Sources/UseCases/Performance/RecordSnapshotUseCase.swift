//
//  RecordSnapshotUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 오늘자 총자산 스냅샷을 남긴다.
///
/// 앱을 며칠 켜지 않으면 그래프에 구멍이 생기므로, 마지막 기록과 오늘 사이의 빈 날은
/// 직전 값으로 채워서 함께 저장한다.
public protocol RecordSnapshotUseCaseProtocol: Sendable {
    @discardableResult
    func execute(asOf date: Date, exchangeRate: ExchangeRate) async throws -> NetWorthRecord
}

public struct RecordSnapshotUseCase: RecordSnapshotUseCaseProtocol {
    // MARK: - Property

    private let snapshotRepository: any SnapshotRepositoryProtocol
    private let fetchNetWorthUseCase: any FetchNetWorthUseCaseProtocol
    private let calendar: Calendar

    // MARK: - Function

    public init(
        snapshotRepository: any SnapshotRepositoryProtocol,
        fetchNetWorthUseCase: any FetchNetWorthUseCaseProtocol,
        calendar: Calendar = .current
    ) {
        self.snapshotRepository = snapshotRepository
        self.fetchNetWorthUseCase = fetchNetWorthUseCase
        self.calendar = calendar
    }

    @discardableResult
    public func execute(asOf date: Date, exchangeRate: ExchangeRate) async throws -> NetWorthRecord {
        let netWorthInKRW = try await fetchNetWorthUseCase.execute(
            baseCurrency: .krw,
            exchangeRate: exchangeRate
        )
        let current = NetWorthRecord(
            recordedOn: calendar.startOfDay(for: date),
            totalInKRW: netWorthInKRW.total,
            totalInUSD: exchangeRate.convert(netWorthInKRW.total, to: .usd),
            categorySubtotals: netWorthInKRW.categorySubtotals
        )

        let latest = try await snapshotRepository.latest()
        try await snapshotRepository.save(
            Self.backfilled(latest: latest, current: current, calendar: calendar)
        )
        return current
    }

    /// 마지막 기록 다음 날부터 오늘 직전까지를 직전 값으로 메운 뒤 오늘치를 덧붙인다.
    static func backfilled(
        latest: NetWorthRecord?,
        current: NetWorthRecord,
        calendar: Calendar
    ) -> [NetWorthRecord] {
        guard let latest else { return [current] }

        var records: [NetWorthRecord] = []
        var day = calendar.startOfDay(for: latest.recordedOn)
        let today = calendar.startOfDay(for: current.recordedOn)

        while let next = calendar.date(byAdding: .day, value: 1, to: day), next < today {
            records.append(latest.carriedForward(to: next))
            day = next
        }

        records.append(current)
        return records
    }
}
