//
//  JournalRepositoryTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunData
import HannunDomain
import HannunTestSupport
import Testing

@Suite("JournalRepository")
struct JournalRepositoryTests {
    private struct Context {
        let journals: JournalRepository
        let holdings: HoldingRepository
    }

    private func makeContext() throws -> Context {
        let container = try HannunModelContainer.make(inMemory: true)
        return Context(
            journals: JournalRepository(modelContainer: container),
            holdings: HoldingRepository(modelContainer: container)
        )
    }

    @Test("일지를 저장하고 다시 읽는다")
    func savesAndFetches() async throws {
        let context = try makeContext()
        let entry = SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 3, 1),
            title: "반도체 비중 축소",
            content: "수요 둔화 우려"
        )

        try await context.journals.save(entry)

        let stored = try #require(await context.journals.fetchAll().first)
        #expect(stored.title == "반도체 비중 축소")
        #expect(stored.content == "수요 둔화 우려")
        #expect(stored.holdingIDs.isEmpty)
    }

    @Test("최신 일지가 앞에 온다")
    func sortsNewestFirst() async throws {
        let context = try makeContext()
        try await context.journals.save(
            SampleRecords.journal(writtenAt: SampleRecords.day(2026, 3, 1), title: "먼저")
        )
        try await context.journals.save(
            SampleRecords.journal(writtenAt: SampleRecords.day(2026, 3, 5), title: "나중")
        )

        #expect(try await context.journals.fetchAll().map(\.title) == ["나중", "먼저"])
    }

    @Test("종목 태그를 저장하고 종목으로 되찾는다")
    func linksHoldings() async throws {
        let context = try makeContext()
        let holding = SampleRecords.holding(
            category: .domesticStock,
            name: "삼성전자",
            ticker: "005930",
            quantity: 10,
            averagePrice: 70_000
        )
        try await context.holdings.save(holding)

        try await context.journals.save(
            SampleRecords.journal(
                writtenAt: SampleRecords.day(2026, 3, 1),
                title: "삼성전자 매수",
                holdingIDs: [holding.id]
            )
        )
        try await context.journals.save(
            SampleRecords.journal(
                writtenAt: SampleRecords.day(2026, 3, 2),
                title: "관련 없는 기록"
            )
        )

        let tagged = try await context.journals.fetch(holdingID: holding.id)
        #expect(tagged.map(\.title) == ["삼성전자 매수"])
        #expect(tagged.first?.holdingIDs == [holding.id])
    }

    @Test("태그를 비우면 연결이 끊긴다")
    func clearsHoldingLink() async throws {
        let context = try makeContext()
        let holding = SampleRecords.holding(category: .cash, name: "현금", quantity: 100)
        try await context.holdings.save(holding)

        var entry = SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 3, 1),
            title: "현금 점검",
            holdingIDs: [holding.id]
        )
        try await context.journals.save(entry)
        entry.holdingIDs = []
        try await context.journals.save(entry)

        #expect(try await context.journals.fetch(holdingID: holding.id).isEmpty)
        #expect(try await context.journals.fetchAll().count == 1)
    }

    @Test("삭제한 일지는 조회되지 않는다")
    func deletes() async throws {
        let context = try makeContext()
        let entry = SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 3, 1),
            title: "삭제 대상"
        )
        try await context.journals.save(entry)

        try await context.journals.delete(id: entry.id)

        #expect(try await context.journals.fetchAll().isEmpty)
    }

    @Test("없는 종목을 태그하면 무시된다")
    func ignoresUnknownHolding() async throws {
        let context = try makeContext()

        try await context.journals.save(
            SampleRecords.journal(
                writtenAt: SampleRecords.day(2026, 3, 1),
                title: "유령 태그",
                holdingIDs: [UUID()]
            )
        )

        #expect(try await context.journals.fetchAll().first?.holdingIDs.isEmpty == true)
    }
}
