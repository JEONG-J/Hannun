//
//  JournalListViewModelTests.swift
//  JournalFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDomain
import Testing
@testable import JournalFeature

@Suite("JournalListViewModel")
@MainActor
struct JournalListViewModelTests {
    @Test("일지를 최신순으로 불러온다")
    func loadsEntriesLatestFirst() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.visibleEntries.map(\.title) == [
            "애플 추가 매수",
            "반도체 비중 축소",
            "현금 비중 유지",
        ])
    }

    @Test("일지가 없으면 빈 상태를 표시한다")
    func showsEmptyPlaceholderWithoutEntries() async {
        let viewModel = makeViewModel(entries: [])

        await viewModel.load()

        #expect(viewModel.placeholder == .noEntry)
    }

    @Test("종목 필터를 고르면 해당 종목이 태그된 일지만 남는다")
    func filtersEntriesByHolding() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        await viewModel.selectHolding(JournalFixture.apple.id)

        #expect(viewModel.selectedHoldingID == JournalFixture.apple.id)
        #expect(viewModel.visibleEntries.map(\.title) == ["애플 추가 매수"])
    }

    @Test("필터를 전체로 되돌리면 모든 일지가 다시 보인다")
    func clearsHoldingFilter() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        await viewModel.selectHolding(JournalFixture.samsung.id)

        await viewModel.selectHolding(nil)

        #expect(viewModel.visibleEntries.count == 3)
    }

    @Test("검색어가 제목과 본문을 함께 훑는다")
    func filtersEntriesBySearchText() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.searchText = "환율"

        #expect(viewModel.visibleEntries.map(\.title) == ["반도체 비중 축소"])
    }

    @Test("조건이 전부 걸러내면 빈 상태가 아니라 결과 없음이다")
    func distinguishesNoMatchFromNoEntry() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.searchText = "존재하지 않는 문구"

        #expect(viewModel.placeholder == .noMatch)
    }

    @Test("일지에 달린 종목 식별자를 종목명으로 바꾼다")
    func mapsHoldingIdentifiersToNames() async throws {
        let viewModel = makeViewModel()
        await viewModel.load()

        let entry = try #require(viewModel.visibleEntries.first)

        #expect(viewModel.tagNames(for: entry) == ["AAPL"])
    }

    @Test("이름을 찾지 못한 태그는 그리지 않는다")
    func skipsUnknownHoldingTags() async throws {
        let viewModel = makeViewModel(holdings: [])
        await viewModel.load()

        let entry = try #require(viewModel.visibleEntries.first)

        #expect(viewModel.tagNames(for: entry).isEmpty)
    }

    @Test("목록 조회가 실패하면 인라인 실패 상태가 된다")
    func reportsFetchFailureInline() async {
        let viewModel = JournalListViewModel(
            fetchJournal: FailingFetchJournalUseCase(error: .persistence("읽기 실패")),
            fetchHoldings: JournalFixture.fetchHoldings()
        )

        await viewModel.load()

        #expect(viewModel.entriesState.error == .persistence("읽기 실패"))
    }

    @Test("종목 목록만 실패해도 일지는 그대로 보인다")
    func keepsEntriesWhenHoldingTagsFail() async {
        let viewModel = JournalListViewModel(
            fetchJournal: JournalFixture.fetchJournal(JournalFixture.entries),
            fetchHoldings: FailingFetchHoldingsUseCase(error: .network("연결 실패"))
        )

        await viewModel.load()

        #expect(viewModel.visibleEntries.count == 3)
        #expect(viewModel.holdingTagsState.error != nil)
    }

    // MARK: - Function

    private func makeViewModel(
        entries: [JournalRecord] = JournalFixture.entries,
        holdings: [HoldingRecord] = JournalFixture.holdings
    ) -> JournalListViewModel {
        JournalListViewModel(
            fetchJournal: JournalFixture.fetchJournal(entries),
            fetchHoldings: JournalFixture.fetchHoldings(holdings)
        )
    }
}
