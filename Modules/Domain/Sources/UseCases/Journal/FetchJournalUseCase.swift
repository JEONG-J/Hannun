//
//  FetchJournalUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 매매일지 목록을 최신순으로 가져온다.
public protocol FetchJournalUseCaseProtocol: Sendable {
    /// `holdingID` 를 주면 해당 종목이 태그된 일지만 추린다.
    func execute(holdingID: UUID?) async throws -> [JournalRecord]
}

public struct FetchJournalUseCase: FetchJournalUseCaseProtocol {
    // MARK: - Property

    private let journalRepository: any JournalRepositoryProtocol

    // MARK: - Function

    public init(journalRepository: any JournalRepositoryProtocol) {
        self.journalRepository = journalRepository
    }

    public func execute(holdingID: UUID?) async throws -> [JournalRecord] {
        guard let holdingID else {
            return try await journalRepository.fetchAll()
        }
        return try await journalRepository.fetch(holdingID: holdingID)
    }
}
