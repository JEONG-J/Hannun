//
//  SaveJournalUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 매매일지를 추가하거나 수정한다.
public protocol SaveJournalUseCaseProtocol: Sendable {
    func execute(_ entry: JournalRecord) async throws
}

public struct SaveJournalUseCase: SaveJournalUseCaseProtocol {
    // MARK: - Property

    private let journalRepository: any JournalRepositoryProtocol
    private let now: @Sendable () -> Date

    // MARK: - Function

    public init(
        journalRepository: any JournalRepositoryProtocol,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.journalRepository = journalRepository
        self.now = now
    }

    public func execute(_ entry: JournalRecord) async throws {
        try await journalRepository.save(Self.validated(entry, now: now()))
    }

    static func validated(_ entry: JournalRecord, now: Date) throws -> JournalRecord {
        var normalized = entry
        normalized.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.content = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.updatedAt = now

        guard !normalized.title.isEmpty else {
            throw AppError.validation("제목을 입력해 주세요.")
        }
        return normalized
    }
}
