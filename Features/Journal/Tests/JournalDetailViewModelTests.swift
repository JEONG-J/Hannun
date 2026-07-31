//
//  JournalDetailViewModelTests.swift
//  JournalFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDomain
import HannunTestSupport
import Testing
@testable import JournalFeature

@Suite("JournalDetailViewModel")
@MainActor
struct JournalDetailViewModelTests {
    @Test("삭제는 확인 다이얼로그를 먼저 띄운다")
    func asksBeforeDeleting() throws {
        let entry = JournalFixture.entries[0]
        let viewModel = makeViewModel(record: entry)

        viewModel.requestDelete()

        let prompt = try #require(viewModel.alertPrompt)
        #expect(prompt.isDestructive)
        #expect(viewModel.deletedEntryID == nil)
    }

    @Test("확인을 누르면 일지가 저장소에서 사라진다")
    func deletesAfterConfirmation() async throws {
        let entry = JournalFixture.entries[0]
        let repository = InMemoryJournalRepository([entry])
        let viewModel = makeViewModel(record: entry, repository: repository)

        await viewModel.delete()

        #expect(viewModel.deletedEntryID == entry.id)
        #expect(await repository.fetchAll().isEmpty)
    }

    @Test("삭제 실패는 전역 Alert 으로 넘긴다")
    func routesDeleteFailureToErrorHandler() async {
        let entry = JournalFixture.entries[0]
        let errorHandler = ErrorHandler()
        let viewModel = JournalDetailViewModel(
            record: entry,
            deleteJournal: FailingDeleteJournalUseCase(error: .persistence("삭제 실패")),
            errorHandler: errorHandler
        )

        await viewModel.delete()

        #expect(viewModel.deletedEntryID == nil)
        #expect(errorHandler.presentedError?.error == .persistence("삭제 실패"))
        #expect(errorHandler.presentedError?.canRetry == true)
    }

    @Test("수정 결과를 받으면 표시 중인 내용을 갈아끼운다")
    func appliesEditedRecord() {
        let entry = JournalFixture.entries[0]
        let viewModel = makeViewModel(record: entry)

        var edited = entry
        edited.title = "제목을 고쳤다"
        viewModel.apply(edited)

        #expect(viewModel.record.title == "제목을 고쳤다")
    }

    // MARK: - Function

    private func makeViewModel(
        record: JournalRecord,
        repository: InMemoryJournalRepository = InMemoryJournalRepository()
    ) -> JournalDetailViewModel {
        JournalDetailViewModel(
            record: record,
            deleteJournal: DeleteJournalUseCase(journalRepository: repository),
            errorHandler: ErrorHandler()
        )
    }
}
