//
//  InMemoryCashFlowRepository.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain

/// `CashFlowRepositoryProtocol` 대역.
public actor InMemoryCashFlowRepository: CashFlowRepositoryProtocol {
    // MARK: - Property

    private var records: [CashFlowRecord]

    // MARK: - Function

    public init(_ records: [CashFlowRecord] = []) {
        self.records = records
    }

    public func fetchAll() -> [CashFlowRecord] {
        records.sorted { $0.occurredOn < $1.occurredOn }
    }

    public func fetch(from startDate: Date, to endDate: Date) -> [CashFlowRecord] {
        fetchAll().filter { $0.occurredOn >= startDate && $0.occurredOn <= endDate }
    }

    public func save(_ event: CashFlowRecord) {
        if let index = records.firstIndex(where: { $0.id == event.id }) {
            records[index] = event
        } else {
            records.append(event)
        }
    }

    public func delete(id: UUID) {
        records.removeAll { $0.id == id }
    }
}
