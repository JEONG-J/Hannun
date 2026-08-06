//
//  JournalListViewModelTests.swift
//  JournalFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
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

    /// 칩 줄이 툴바 메뉴로 바뀌면서 고른 종목이 화면에 글자로 남지 않는다 — 메뉴 버튼의
    /// 접근성 값과 채운 아이콘이 그 자리를 대신하므로 이름을 꺼내올 수 있어야 한다.
    @Test("고른 종목의 이름을 툴바가 읽을 수 있게 내준다")
    func exposesSelectedHoldingName() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        await viewModel.selectHolding(JournalFixture.samsung.id)

        #expect(viewModel.selectedHoldingName == "삼성전자")
    }

    @Test("필터가 없거나 종목이 사라졌으면 읽을 이름도 없다")
    func hasNoSelectedHoldingNameWithoutMatch() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        #expect(viewModel.selectedHoldingName == nil)

        await viewModel.selectHolding(UUID())

        #expect(viewModel.selectedHoldingName == nil)
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

    /// 결과 0건 화면의 "검색·필터 해제" 가 누르는 자리. 둘 중 하나만 풀면 여전히 0건인
    /// 화면이 남을 수 있어 한 번에 둘 다 푼다.
    @Test("검색·필터 해제는 검색어와 종목 필터를 함께 되돌린다")
    func clearsSearchAndHoldingFilterTogether() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        await viewModel.selectHolding(JournalFixture.samsung.id)
        viewModel.searchText = "존재하지 않는 문구"
        #expect(viewModel.placeholder == .noMatch)

        await viewModel.clearFilters()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedHoldingID == nil)
        #expect(viewModel.placeholder == nil)
        #expect(viewModel.visibleEntries.count == 3)
    }

    /// 태그 캡슐이 분류색을 입으므로 이름만이 아니라 분류까지 따라와야 한다.
    @Test("일지에 달린 종목 식별자를 종목으로 되돌린다")
    func mapsHoldingIdentifiersToHoldings() async throws {
        let viewModel = makeViewModel()
        await viewModel.load()

        let entry = try #require(viewModel.visibleEntries.first)
        let tagged = viewModel.taggedHoldings(for: entry)

        #expect(tagged.map(\.name) == ["AAPL"])
        #expect(tagged.map(\.category) == [.overseasStock])
    }

    @Test("종목을 찾지 못한 태그는 그리지 않는다")
    func skipsUnknownHoldingTags() async throws {
        let viewModel = makeViewModel(holdings: [])
        await viewModel.load()

        let entry = try #require(viewModel.visibleEntries.first)

        #expect(viewModel.taggedHoldings(for: entry).isEmpty)
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
