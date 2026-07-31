//
//  DeleteJournalUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 매매일지를 제거한다. 확인 다이얼로그는 Presentation 이 띄운다.
public protocol DeleteJournalUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
}

public struct DeleteJournalUseCase: DeleteJournalUseCaseProtocol {
    // MARK: - Property

    private let journalRepository: any JournalRepositoryProtocol

    // MARK: - Function

    public init(journalRepository: any JournalRepositoryProtocol) {
        self.journalRepository = journalRepository
    }

    public func execute(id: UUID) async throws {
        try await journalRepository.delete(id: id)
    }
}
