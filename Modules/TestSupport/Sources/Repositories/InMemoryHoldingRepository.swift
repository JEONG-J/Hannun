//
//  InMemoryHoldingRepository.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// UseCase 를 저장소 없이 검증하기 위한 `HoldingRepositoryProtocol` 대역.
public actor InMemoryHoldingRepository: HoldingRepositoryProtocol {
    // MARK: - Property

    private var records: [HoldingRecord]

    // MARK: - Function

    public init(_ records: [HoldingRecord] = []) {
        self.records = records
    }

    public func fetchAll() -> [HoldingRecord] {
        records.sorted { $0.createdAt < $1.createdAt }
    }

    public func fetch(category: AssetCategory) -> [HoldingRecord] {
        fetchAll().filter { $0.category == category }
    }

    public func fetch(id: UUID) -> HoldingRecord? {
        records.first { $0.id == id }
    }

    public func save(_ holding: HoldingRecord) {
        if let index = records.firstIndex(where: { $0.id == holding.id }) {
            records[index] = holding
        } else {
            records.append(holding)
        }
    }

    public func delete(id: UUID) {
        records.removeAll { $0.id == id }
    }
}
