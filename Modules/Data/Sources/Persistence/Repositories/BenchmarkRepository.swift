//
//  BenchmarkRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain
import SwiftData

/// 벤치마크 지수 시세 캐시의 SwiftData 구현.
@ModelActor
public actor BenchmarkRepository: BenchmarkRepositoryProtocol {
    // MARK: - Function

    public func fetch(
        index: BenchmarkIndex,
        from startDate: Date,
        to endDate: Date
    ) throws -> [BenchmarkRecord] {
        let rawValue = index.rawValue
        let descriptor = FetchDescriptor<BenchmarkSnapshot>(
            predicate: #Predicate {
                $0.indexRawValue == rawValue
                    && $0.recordedOn >= startDate
                    && $0.recordedOn <= endDate
            },
            sortBy: [SortDescriptor(\.recordedOn, order: .forward)]
        )

        return try persisting {
            try modelContext.fetch(descriptor).map(\.record)
        }
    }

    public func save(_ records: [BenchmarkRecord]) throws {
        try persisting {
            for record in records {
                if let existing = try entity(index: record.index, on: record.recordedOn) {
                    existing.apply(record)
                } else {
                    modelContext.insert(BenchmarkSnapshot(record: record))
                }
            }
            try modelContext.save()
        }
    }

    /// 같은 지수·같은 날의 시세는 한 건만 남긴다.
    private func entity(index: BenchmarkIndex, on date: Date) throws -> BenchmarkSnapshot? {
        let calendar = Calendar.current
        let rawValue = index.rawValue
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        var descriptor = FetchDescriptor<BenchmarkSnapshot>(
            predicate: #Predicate {
                $0.indexRawValue == rawValue
                    && $0.recordedOn >= dayStart
                    && $0.recordedOn < dayEnd
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
