//
//  BenchmarkRepositoryProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 벤치마크 지수 시세 캐시 저장소.
public protocol BenchmarkRepositoryProtocol: Sendable {
    /// 경계 포함 구간을 기록 일자 오름차순으로 돌려준다.
    func fetch(
        index: BenchmarkIndex,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [BenchmarkRecord]

    /// 같은 지수·같은 날짜의 기록이 있으면 덮어쓴다.
    func save(_ records: [BenchmarkRecord]) async throws
}
