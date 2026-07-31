//
//  DeleteHoldingUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 보유 종목을 제거한다. 확인 다이얼로그는 Presentation 이 띄운다.
public protocol DeleteHoldingUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
}

public struct DeleteHoldingUseCase: DeleteHoldingUseCaseProtocol {
    // MARK: - Property

    private let holdingRepository: any HoldingRepositoryProtocol

    // MARK: - Function

    public init(holdingRepository: any HoldingRepositoryProtocol) {
        self.holdingRepository = holdingRepository
    }

    public func execute(id: UUID) async throws {
        try await holdingRepository.delete(id: id)
    }
}
