//
//  JournalRepositoryProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 매매일지 저장소.
public protocol JournalRepositoryProtocol: Sendable {
    /// 작성 시각 내림차순 (최신순).
    func fetchAll() async throws -> [JournalRecord]

    /// 해당 종목이 태그된 일지만 최신순으로 돌려준다.
    func fetch(holdingID: UUID) async throws -> [JournalRecord]

    func save(_ entry: JournalRecord) async throws
    func delete(id: UUID) async throws
}
