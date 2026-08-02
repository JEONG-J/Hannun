//
//  InMemorySnapshotRepository.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// `SnapshotRepositoryProtocol` 대역. 실제 구현과 같이 같은 날짜의 기록을 덮어쓴다.
///
/// `failure` 를 주면 구간 조회가 실패하는 상황을 재현한다 — 기록이 없는 상태와 저장소가
/// 망가진 상태를 구분해 검증하기 위해서다.
public actor InMemorySnapshotRepository: SnapshotRepositoryProtocol {
    // MARK: - Property

    private var records: [NetWorthRecord]
    private let calendar: Calendar
    private let failure: AppError?

    // MARK: - Function

    public init(
        _ records: [NetWorthRecord] = [],
        calendar: Calendar = .current,
        failure: AppError? = nil
    ) {
        self.records = records
        self.calendar = calendar
        self.failure = failure
    }

    public func fetchAll() -> [NetWorthRecord] {
        records.sorted { $0.recordedOn < $1.recordedOn }
    }

    public func fetch(from startDate: Date, to endDate: Date) throws -> [NetWorthRecord] {
        if let failure { throw failure }

        return fetchAll().filter { $0.recordedOn >= startDate && $0.recordedOn <= endDate }
    }

    public func latest() -> NetWorthRecord? {
        fetchAll().last
    }

    public func save(_ newRecords: [NetWorthRecord]) {
        for record in newRecords {
            let day = calendar.startOfDay(for: record.recordedOn)
            let index = records.firstIndex {
                calendar.startOfDay(for: $0.recordedOn) == day
            }

            if let index {
                records[index] = record
            } else {
                records.append(record)
            }
        }
    }
}
