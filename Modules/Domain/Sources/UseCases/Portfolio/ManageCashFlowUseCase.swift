//
//  ManageCashFlowUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 입출금 기록의 조회·추가·수정·삭제.
///
/// 이 기록이 바뀌면 YTD 수익률이 함께 바뀌므로, 성과 탭은 저장 후 다시 계산해야 한다.
public protocol ManageCashFlowUseCaseProtocol: Sendable {
    func fetchAll() async throws -> [CashFlowRecord]
    func save(_ event: CashFlowRecord) async throws
    func delete(id: UUID) async throws
}

public struct ManageCashFlowUseCase: ManageCashFlowUseCaseProtocol {
    // MARK: - Property

    private let cashFlowRepository: any CashFlowRepositoryProtocol

    // MARK: - Function

    public init(cashFlowRepository: any CashFlowRepositoryProtocol) {
        self.cashFlowRepository = cashFlowRepository
    }

    public func fetchAll() async throws -> [CashFlowRecord] {
        try await cashFlowRepository.fetchAll()
    }

    public func save(_ event: CashFlowRecord) async throws {
        try await cashFlowRepository.save(Self.validated(event))
    }

    public func delete(id: UUID) async throws {
        try await cashFlowRepository.delete(id: id)
    }

    static func validated(_ event: CashFlowRecord) throws -> CashFlowRecord {
        guard event.amount > 0 else {
            throw AppError.validation("금액은 0보다 커야 해요.")
        }

        var normalized = event
        normalized.memo = event.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }
}
