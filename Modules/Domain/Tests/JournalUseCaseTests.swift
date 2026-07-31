//
//  JournalUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("SaveJournalUseCase")
struct SaveJournalUseCaseTests {
    private let writtenAt = SampleRecords.day(2026, 3, 1)

    @Test("제목이 비면 저장하지 않는다")
    func rejectsEmptyTitle() {
        #expect(throws: AppError.validation("제목을 입력해 주세요.")) {
            try SaveJournalUseCase.validated(
                SampleRecords.journal(writtenAt: writtenAt, title: "  "),
                now: writtenAt
            )
        }
    }

    @Test("제목과 본문의 앞뒤 공백을 지우고 수정 시각을 갱신한다")
    func normalizesText() throws {
        let updatedAt = SampleRecords.day(2026, 3, 2)
        let normalized = try SaveJournalUseCase.validated(
            SampleRecords.journal(
                writtenAt: writtenAt,
                title: " 반도체 비중 축소 ",
                content: " 이유: 수요 둔화\n"
            ),
            now: updatedAt
        )

        #expect(normalized.title == "반도체 비중 축소")
        #expect(normalized.content == "이유: 수요 둔화")
        #expect(normalized.updatedAt == updatedAt)
    }

    @Test("같은 식별자로 저장하면 덮어쓴다")
    func updatesExistingEntry() async throws {
        let repository = InMemoryJournalRepository()
        let useCase = SaveJournalUseCase(journalRepository: repository)
        let entry = SampleRecords.journal(writtenAt: writtenAt, title: "첫 기록")

        try await useCase.execute(entry)
        var edited = entry
        edited.title = "고친 기록"
        try await useCase.execute(edited)

        let stored = await repository.fetchAll()
        #expect(stored.count == 1)
        #expect(stored.first?.title == "고친 기록")
    }
}

@Suite("FetchJournalUseCase")
struct FetchJournalUseCaseTests {
    private let holdingID = UUID()

    private var entries: [JournalRecord] {
        [
            SampleRecords.journal(
                writtenAt: SampleRecords.day(2026, 3, 1),
                title: "삼성전자 매수",
                holdingIDs: [holdingID]
            ),
            SampleRecords.journal(
                writtenAt: SampleRecords.day(2026, 3, 5),
                title: "현금 비중 점검"
            ),
        ]
    }

    @Test("일지는 최신순으로 나온다")
    func sortsNewestFirst() async throws {
        let useCase = FetchJournalUseCase(
            journalRepository: InMemoryJournalRepository(entries)
        )

        let records = try await useCase.execute(holdingID: nil)

        #expect(records.map(\.title) == ["현금 비중 점검", "삼성전자 매수"])
    }

    @Test("종목으로 거르면 태그된 일지만 남는다")
    func filtersByHolding() async throws {
        let useCase = FetchJournalUseCase(
            journalRepository: InMemoryJournalRepository(entries)
        )

        let records = try await useCase.execute(holdingID: holdingID)

        #expect(records.map(\.title) == ["삼성전자 매수"])
    }
}

@Suite("DeleteJournalUseCase")
struct DeleteJournalUseCaseTests {
    @Test("삭제한 일지는 목록에서 사라진다")
    func removesEntry() async throws {
        let entry = SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 3, 1),
            title: "삭제 대상"
        )
        let repository = InMemoryJournalRepository([entry])

        try await DeleteJournalUseCase(journalRepository: repository).execute(id: entry.id)

        #expect(await repository.fetchAll().isEmpty)
    }
}
