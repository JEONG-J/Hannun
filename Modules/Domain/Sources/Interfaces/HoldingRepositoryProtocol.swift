//
//  HoldingRepositoryProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 보유 종목 저장소. 구현은 `HannunData` 의 SwiftData Repository 다.
public protocol HoldingRepositoryProtocol: Sendable {
    /// 생성 순서 오름차순.
    func fetchAll() async throws -> [HoldingRecord]
    func fetch(category: AssetCategory) async throws -> [HoldingRecord]
    func fetch(id: UUID) async throws -> HoldingRecord?

    /// 같은 식별자가 있으면 갱신하고 없으면 새로 만든다.
    func save(_ holding: HoldingRecord) async throws
    func delete(id: UUID) async throws
}
