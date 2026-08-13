//
//  SaveHoldingUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 보유 종목을 추가하거나 수정한다.
///
/// CloudKit 스키마 제약 때문에 엔티티는 모든 필드에 기본값을 갖는다 —
/// "종목명 필수" 같은 규칙은 저장 직전인 여기서 검증한다.
public protocol SaveHoldingUseCaseProtocol: Sendable {
    func execute(_ holding: HoldingRecord) async throws
}

public struct SaveHoldingUseCase: SaveHoldingUseCaseProtocol {
    // MARK: - Property

    private let holdingRepository: any HoldingRepositoryProtocol

    // MARK: - Function

    public init(holdingRepository: any HoldingRepositoryProtocol) {
        self.holdingRepository = holdingRepository
    }

    public func execute(_ holding: HoldingRecord) async throws {
        try await holdingRepository.save(Self.validated(holding))
    }

    static func validated(_ holding: HoldingRecord) throws -> HoldingRecord {
        var normalized = holding
        normalized.name = holding.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.ticker = holding.ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.updatedAt = Date()

        guard !normalized.name.isEmpty else {
            throw AppError.validation("종목명을 입력해 주세요.")
        }
        guard normalized.quantity > 0 else {
            throw AppError.validation("수량은 0보다 커야 해요.")
        }

        guard !normalized.category.isBalanceOnly else {
            // 현금·대출은 평단가·티커 개념이 없다. 잘못 들어온 값을 여기서 떨어뜨린다.
            // 대출 잔액도 양수로 받는다 — 부호는 평가 시점에만 붙는다.
            normalized.averagePrice = nil
            normalized.manualPrice = nil
            normalized.ticker = ""
            return normalized
        }

        guard !normalized.ticker.isEmpty else {
            throw AppError.validation("티커·종목코드를 입력해 주세요.")
        }
        guard let averagePrice = normalized.averagePrice, averagePrice > 0 else {
            throw AppError.validation("평단가를 입력해 주세요.")
        }

        return normalized
    }
}
