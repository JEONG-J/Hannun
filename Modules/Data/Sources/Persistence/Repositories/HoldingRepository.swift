//
//  HoldingRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import SwiftData

/// 보유 종목 저장소의 SwiftData 구현.
///
/// `@Model` 인스턴스는 `Sendable` 이 아니라서 액터 밖으로 내보내지 않고, 경계에서 `HoldingRecord`
/// 값 타입으로 바꿔 넘긴다.
@ModelActor
public actor HoldingRepository: HoldingRepositoryProtocol {
    // MARK: - Function

    public func fetchAll() throws -> [HoldingRecord] {
        try persisting {
            try modelContext.fetch(Self.sortedByCreation()).map(\.record)
        }
    }

    public func fetch(category: AssetCategory) throws -> [HoldingRecord] {
        let rawValue = category.rawValue
        var descriptor = Self.sortedByCreation()
        descriptor.predicate = #Predicate<Holding> { $0.categoryRawValue == rawValue }

        return try persisting {
            try modelContext.fetch(descriptor).map(\.record)
        }
    }

    public func fetch(id: UUID) throws -> HoldingRecord? {
        try persisting {
            try entity(id: id)?.record
        }
    }

    public func save(_ holding: HoldingRecord) throws {
        try persisting {
            if let existing = try entity(id: holding.id) {
                existing.apply(holding)
            } else {
                modelContext.insert(Holding(record: holding))
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

    private func entity(id: UUID) throws -> Holding? {
        var descriptor = FetchDescriptor<Holding>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func sortedByCreation() -> FetchDescriptor<Holding> {
        FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
    }
}
