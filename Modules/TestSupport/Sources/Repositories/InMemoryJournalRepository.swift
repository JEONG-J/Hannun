//
//  InMemoryJournalRepository.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain

/// `JournalRepositoryProtocol` 대역.
public actor InMemoryJournalRepository: JournalRepositoryProtocol {
    // MARK: - Property

    private var records: [JournalRecord]

    // MARK: - Function

    public init(_ records: [JournalRecord] = []) {
        self.records = records
    }

    public func fetchAll() -> [JournalRecord] {
        records.sorted { $0.writtenAt > $1.writtenAt }
    }

    public func fetch(holdingID: UUID) -> [JournalRecord] {
        fetchAll().filter { $0.holdingIDs.contains(holdingID) }
    }

    public func save(_ entry: JournalRecord) {
        if let index = records.firstIndex(where: { $0.id == entry.id }) {
            records[index] = entry
        } else {
            records.append(entry)
        }
    }

    public func delete(id: UUID) {
        records.removeAll { $0.id == id }
    }
}
