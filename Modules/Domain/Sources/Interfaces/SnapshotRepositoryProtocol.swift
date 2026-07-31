//
//  SnapshotRepositoryProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 총자산 스냅샷 저장소.
public protocol SnapshotRepositoryProtocol: Sendable {
    /// 기록 일자 오름차순.
    func fetchAll() async throws -> [NetWorthRecord]

    /// 경계 포함 구간 조회.
    func fetch(from startDate: Date, to endDate: Date) async throws -> [NetWorthRecord]

    func latest() async throws -> NetWorthRecord?

    /// 같은 날짜의 기록이 있으면 덮어쓴다 — 하루 한 건이 스냅샷의 단위다.
    func save(_ records: [NetWorthRecord]) async throws
}
