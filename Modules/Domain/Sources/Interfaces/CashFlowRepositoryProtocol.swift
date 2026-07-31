//
//  CashFlowRepositoryProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 입출금 기록 저장소.
public protocol CashFlowRepositoryProtocol: Sendable {
    /// 발생일 오름차순.
    func fetchAll() async throws -> [CashFlowRecord]

    /// 경계 포함 구간 조회.
    func fetch(from startDate: Date, to endDate: Date) async throws -> [CashFlowRecord]

    func save(_ event: CashFlowRecord) async throws
    func delete(id: UUID) async throws
}
