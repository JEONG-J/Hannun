//
//  CashFlowRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain
import SwiftData

/// 입출금 기록 저장소의 SwiftData 구현.
@ModelActor
public actor CashFlowRepository: CashFlowRepositoryProtocol {
    // MARK: - Function

    public func fetchAll() throws -> [CashFlowRecord] {
        try persisting {
            try modelContext.fetch(Self.sortedByDate()).map(\.record)
        }
    }

    public func fetch(from startDate: Date, to endDate: Date) throws -> [CashFlowRecord] {
        var descriptor = Self.sortedByDate()
        descriptor.predicate = #Predicate<CashFlowEvent> {
            $0.occurredOn >= startDate && $0.occurredOn <= endDate
        }

        return try persisting {
            try modelContext.fetch(descriptor).map(\.record)
        }
    }

    public func save(_ event: CashFlowRecord) throws {
        try persisting {
            if let existing = try entity(id: event.id) {
                existing.apply(event)
            } else {
                modelContext.insert(CashFlowEvent(record: event))
            }
            try modelContext.save()
        }
    }

    public func delete(id: UUID) throws {
        try persisting {
            guard let existing = try entity(id: id) else { return }
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    private func entity(id: UUID) throws -> CashFlowEvent? {
        var descriptor = FetchDescriptor<CashFlowEvent>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func sortedByDate() -> FetchDescriptor<CashFlowEvent> {
        FetchDescriptor<CashFlowEvent>(sortBy: [SortDescriptor(\.occurredOn, order: .forward)])
    }
}
