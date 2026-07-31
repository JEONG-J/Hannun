//
//  SnapshotRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain
import SwiftData

/// 총자산 스냅샷 저장소의 SwiftData 구현.
@ModelActor
public actor SnapshotRepository: SnapshotRepositoryProtocol {
    // MARK: - Function

    public func fetchAll() throws -> [NetWorthRecord] {
        try persisting {
            try modelContext.fetch(Self.sortedByDate()).map(\.record)
        }
    }

    public func fetch(from startDate: Date, to endDate: Date) throws -> [NetWorthRecord] {
        var descriptor = Self.sortedByDate()
        descriptor.predicate = #Predicate<NetWorthSnapshot> {
            $0.recordedOn >= startDate && $0.recordedOn <= endDate
        }

        return try persisting {
            try modelContext.fetch(descriptor).map(\.record)
        }
    }

    public func latest() throws -> NetWorthRecord? {
        var descriptor = FetchDescriptor<NetWorthSnapshot>(
            sortBy: [SortDescriptor(\.recordedOn, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try persisting {
            try modelContext.fetch(descriptor).first?.record
        }
    }

    public func save(_ records: [NetWorthRecord]) throws {
        try persisting {
            for record in records {
                if let existing = try entity(on: record.recordedOn) {
                    existing.apply(record)
                } else {
                    modelContext.insert(NetWorthSnapshot(record: record))
                }
            }
            try modelContext.save()
        }
    }

    /// 하루에 한 건이 스냅샷의 단위라, 시각이 조금 달라도 같은 날이면 같은 기록으로 본다.
    private func entity(on date: Date) throws -> NetWorthSnapshot? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        var descriptor = FetchDescriptor<NetWorthSnapshot>(
            predicate: #Predicate { $0.recordedOn >= dayStart && $0.recordedOn < dayEnd }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func sortedByDate() -> FetchDescriptor<NetWorthSnapshot> {
        FetchDescriptor<NetWorthSnapshot>(sortBy: [SortDescriptor(\.recordedOn, order: .forward)])
    }
}
