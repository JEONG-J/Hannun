//
//  JournalRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain
import SwiftData

/// 매매일지 저장소의 SwiftData 구현.
@ModelActor
public actor JournalRepository: JournalRepositoryProtocol {
    // MARK: - Function

    public func fetchAll() throws -> [JournalRecord] {
        try persisting {
            try modelContext.fetch(Self.newestFirst()).map(\.record)
        }
    }

    /// 관계를 술어로 거르는 대신 종목 쪽에서 역방향으로 읽는다 — 저장소가 번역하지 못하는
    /// to-many 조건을 피하려는 선택이다.
    public func fetch(holdingID: UUID) throws -> [JournalRecord] {
        try persisting {
            var descriptor = FetchDescriptor<Holding>(
                predicate: #Predicate { $0.id == holdingID }
            )
            descriptor.fetchLimit = 1

            guard let holding = try modelContext.fetch(descriptor).first else { return [] }
            return (holding.journalEntries ?? [])
                .map(\.record)
                .sorted { $0.writtenAt > $1.writtenAt }
        }
    }

    public func save(_ entry: JournalRecord) throws {
        try persisting {
            let target: JournalEntry
            if let existing = try entity(id: entry.id) {
                existing.apply(entry)
                target = existing
            } else {
                let created = JournalEntry(record: entry)
                modelContext.insert(created)
                target = created
            }

            target.holdings = try holdings(ids: entry.holdingIDs)
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

    private func entity(id: UUID) throws -> JournalEntry? {
        var descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func holdings(ids: [UUID]) throws -> [Holding] {
        guard !ids.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Holding>(predicate: #Predicate { ids.contains($0.id) })
        return try modelContext.fetch(descriptor)
    }

    private static func newestFirst() -> FetchDescriptor<JournalEntry> {
        FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.writtenAt, order: .reverse)])
    }
}
