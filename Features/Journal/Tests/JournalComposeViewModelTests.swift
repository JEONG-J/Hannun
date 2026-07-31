//
//  JournalComposeViewModelTests.swift
//  JournalFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain
import HannunTestSupport
import Testing
@testable import JournalFeature

@Suite("JournalComposeViewModel")
@MainActor
struct JournalComposeViewModelTests {
    @Test("작성 시각은 사용자 입력 없이 자동으로 기록된다")
    func recordsWrittenAtAutomatically() async {
        let now = SampleRecords.day(2026, 8, 1)
        let viewModel = makeViewModel(now: now)
        viewModel.title = "첫 일지"

        await viewModel.save()

        #expect(viewModel.savedEntry?.writtenAt == now)
    }

    @Test("제목과 본문, 연결 종목을 담아 저장한다")
    func savesTitleContentAndHoldings() async throws {
        let repository = InMemoryJournalRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "반도체 비중 축소"
        viewModel.content = "환율이 밀릴 것 같다."
        viewModel.toggleHolding(JournalFixture.samsung.id)

        await viewModel.save()

        let stored = try #require(await repository.fetchAll().first)
        #expect(stored.title == "반도체 비중 축소")
        #expect(stored.content == "환율이 밀릴 것 같다.")
        #expect(stored.holdingIDs == [JournalFixture.samsung.id])
    }

    @Test("연결 종목은 0개여도 저장된다")
    func savesWithoutHoldings() async {
        let viewModel = makeViewModel()
        viewModel.title = "관망"

        await viewModel.save()

        #expect(viewModel.savedEntry?.holdingIDs.isEmpty == true)
    }

    @Test("제목이 비면 저장에 실패하고 인라인 문구를 남긴다")
    func rejectsEmptyTitle() async {
        let viewModel = makeViewModel()
        viewModel.title = "   "
        viewModel.content = "본문만 있다."

        await viewModel.save()

        #expect(viewModel.savedEntry == nil)
        #expect(viewModel.saveFailure == .validation("제목을 입력해 주세요."))
    }

    @Test("저장 실패도 인라인 상태로만 남는다")
    func reportsSaveFailureInline() async {
        let viewModel = JournalComposeViewModel(
            composition: .draft,
            saveJournal: FailingSaveJournalUseCase(error: .persistence("저장 실패")),
            fetchHoldings: JournalFixture.fetchHoldings()
        )
        viewModel.title = "제목"

        await viewModel.save()

        #expect(viewModel.saveFailure == .persistence("저장 실패"))
    }

    @Test("종목 태그는 눌렀다 다시 누르면 해제된다")
    func togglesHoldingSelection() {
        let viewModel = makeViewModel()

        viewModel.toggleHolding(JournalFixture.apple.id)
        #expect(viewModel.isSelected(JournalFixture.apple.id))

        viewModel.toggleHolding(JournalFixture.apple.id)
        #expect(!viewModel.isSelected(JournalFixture.apple.id))
    }

    @Test("수정 모드는 기존 일지 값으로 시작한다")
    func startsFromExistingEntryWhenEditing() {
        let entry = JournalFixture.entries[1]
        let viewModel = makeViewModel(composition: .revision(of: entry))

        #expect(viewModel.isEditing)
        #expect(viewModel.title == entry.title)
        #expect(viewModel.content == entry.content)
        #expect(viewModel.writtenAt == entry.writtenAt)
        #expect(viewModel.selectedHoldingIDs == entry.holdingIDs)
    }

    @Test("수정 저장은 같은 식별자를 유지한다")
    func keepsIdentifierWhenEditing() async {
        let entry = JournalFixture.entries[1]
        let viewModel = makeViewModel(composition: .revision(of: entry))
        viewModel.title = "제목을 고쳤다"

        await viewModel.save()

        #expect(viewModel.savedEntry?.id == entry.id)
        #expect(viewModel.savedEntry?.title == "제목을 고쳤다")
    }

    @Test("고친 내용이 없으면 확인 없이 닫는다")
    func closesImmediatelyWithoutChanges() {
        let viewModel = makeViewModel()

        viewModel.requestClose()

        #expect(viewModel.isClosed)
        #expect(viewModel.alertPrompt == nil)
    }

    @Test("쓰던 내용이 있으면 확인 다이얼로그를 먼저 띄운다")
    func asksBeforeDiscardingChanges() throws {
        let viewModel = makeViewModel()
        viewModel.title = "쓰다 만 제목"

        viewModel.requestClose()

        let prompt = try #require(viewModel.alertPrompt)
        #expect(!viewModel.isClosed)
        #expect(prompt.isDestructive)

        prompt.confirmAction()
        #expect(viewModel.isClosed)
    }

    @Test("종목 목록을 불러오지 못해도 작성은 계속할 수 있다")
    func allowsComposingWhenHoldingTagsFail() async {
        let viewModel = JournalComposeViewModel(
            composition: .draft,
            saveJournal: SaveJournalUseCase(journalRepository: InMemoryJournalRepository()),
            fetchHoldings: FailingFetchHoldingsUseCase(error: .network("연결 실패"))
        )

        await viewModel.loadHoldingTags()
        viewModel.title = "제목"
        await viewModel.save()

        #expect(viewModel.holdingTagsState.error != nil)
        #expect(viewModel.savedEntry != nil)
    }

    // MARK: - Function

    private func makeViewModel(
        composition: JournalComposition = .draft,
        repository: InMemoryJournalRepository = InMemoryJournalRepository(),
        now: Date = SampleRecords.day(2026, 8, 1)
    ) -> JournalComposeViewModel {
        JournalComposeViewModel(
            composition: composition,
            saveJournal: SaveJournalUseCase(journalRepository: repository, now: { now }),
            fetchHoldings: JournalFixture.fetchHoldings(),
            now: now
        )
    }
}
