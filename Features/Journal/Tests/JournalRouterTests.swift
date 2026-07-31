//
//  JournalRouterTests.swift
//  JournalFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Testing
@testable import JournalFeature

@Suite("JournalRouter")
@MainActor
struct JournalRouterTests {
    @Test("상세로 이동하면 경로가 쌓이고 닫으면 되돌아온다")
    func pushesAndPopsDetail() {
        let router = JournalRouter()
        let entry = JournalFixture.entries[0]

        router.showDetail(of: entry)
        #expect(router.path == [.detail(entry)])

        router.closeDetail()
        #expect(router.path.isEmpty)
    }

    @Test("작성과 수정은 같은 화면을 서로 다른 대상으로 연다")
    func opensCompositionForDraftAndRevision() {
        let router = JournalRouter()
        let entry = JournalFixture.entries[0]

        router.composeNewEntry()
        #expect(router.composition?.editing == nil)

        router.edit(entry)
        #expect(router.composition?.editing == entry)
        #expect(router.composition?.id == entry.id)

        router.dismissComposition()
        #expect(router.composition == nil)
    }

    @Test("열려 있던 상세는 수정 결과로 갱신된다")
    func refreshesOpenDetailAfterEdit() {
        let router = JournalRouter()
        let entry = JournalFixture.entries[0]
        router.showDetail(of: entry)

        var edited = entry
        edited.title = "제목을 고쳤다"
        router.refreshDetail(with: edited)

        #expect(router.path == [.detail(edited)])
    }

    @Test("다른 일지를 저장해도 열려 있는 상세는 건드리지 않는다")
    func keepsDetailWhenOtherEntrySaved() {
        let router = JournalRouter()
        let shown = JournalFixture.entries[0]
        router.showDetail(of: shown)

        router.refreshDetail(with: JournalFixture.entries[1])

        #expect(router.path == [.detail(shown)])
    }
}
