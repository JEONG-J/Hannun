//
//  InMemoryBenchmarkRepository.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// `BenchmarkRepositoryProtocol` 대역. `failure` 를 주면 조회가 실패하는 상황을 재현한다.
public actor InMemoryBenchmarkRepository: BenchmarkRepositoryProtocol {
    // MARK: - Property

    private var records: [BenchmarkRecord]
    private let failure: AppError?

    // MARK: - Function

    public init(_ records: [BenchmarkRecord] = [], failure: AppError? = nil) {
        self.records = records
        self.failure = failure
    }

    public func fetch(
        index: BenchmarkIndex,
        from startDate: Date,
        to endDate: Date
    ) throws -> [BenchmarkRecord] {
        if let failure { throw failure }

        return records
            .filter { $0.index == index && $0.recordedOn >= startDate && $0.recordedOn <= endDate }
            .sorted { $0.recordedOn < $1.recordedOn }
    }

    public func save(_ newRecords: [BenchmarkRecord]) {
        for record in newRecords {
            let index = records.firstIndex {
                $0.index == record.index && $0.recordedOn == record.recordedOn
            }

            if let index {
                records[index] = record
            } else {
                records.append(record)
            }
        }
    }
}
