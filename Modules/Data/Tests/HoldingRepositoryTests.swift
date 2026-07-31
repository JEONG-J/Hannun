//
//  HoldingRepositoryTests.swift
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

@Suite("HoldingRepository")
struct HoldingRepositoryTests {
    private func makeRepository() throws -> HoldingRepository {
        HoldingRepository(modelContainer: try HannunModelContainer.make(inMemory: true))
    }

    @Test("저장한 종목을 식별자로 다시 찾는다")
    func savesAndFetches() async throws {
        let repository = try makeRepository()
        let holding = SampleRecords.holding(
            category: .domesticStock,
            name: "삼성전자",
            ticker: "005930",
            quantity: 10,
            averagePrice: 70_000
        )

        try await repository.save(holding)

        let stored = try #require(await repository.fetch(id: holding.id))
        #expect(stored.name == "삼성전자")
        #expect(stored.ticker == "005930")
        #expect(stored.quantity == 10)
        #expect(stored.averagePrice == 70_000)
        #expect(stored.currency == .krw)
    }

    @Test("같은 식별자로 저장하면 새로 만들지 않고 갱신한다")
    func updatesInPlace() async throws {
        let repository = try makeRepository()
        var holding = SampleRecords.holding(
            category: .crypto,
            name: "비트코인",
            ticker: "KRW-BTC",
            quantity: 1,
            averagePrice: 90_000_000
        )

        try await repository.save(holding)
        holding.quantity = 2
        try await repository.save(holding)

        let stored = try await repository.fetchAll()
        #expect(stored.count == 1)
        #expect(stored.first?.quantity == 2)
    }

    @Test("자산군으로 거를 수 있다")
    func filtersByCategory() async throws {
        let repository = try makeRepository()
        try await repository.save(
            SampleRecords.holding(category: .cash, name: "현금", quantity: 1_000_000)
        )
        try await repository.save(
            SampleRecords.holding(
                category: .overseasStock,
                name: "Apple",
                ticker: "AAPL",
                currency: .usd,
                quantity: 5,
                averagePrice: 150
            )
        )

        let overseas = try await repository.fetch(category: .overseasStock)
        #expect(overseas.map(\.name) == ["Apple"])
        #expect(overseas.first?.currency == .usd)
    }

    @Test("생성 순서대로 돌려준다")
    func sortsByCreation() async throws {
        let repository = try makeRepository()
        try await repository.save(
            SampleRecords.holding(
                category: .cash,
                name: "나중",
                quantity: 1,
                createdAt: SampleRecords.day(2026, 3, 2)
            )
        )
        try await repository.save(
            SampleRecords.holding(
                category: .cash,
                name: "먼저",
                quantity: 1,
                createdAt: SampleRecords.day(2026, 3, 1)
            )
        )

        #expect(try await repository.fetchAll().map(\.name) == ["먼저", "나중"])
    }

    @Test("삭제한 종목은 조회되지 않는다")
    func deletes() async throws {
        let repository = try makeRepository()
        let holding = SampleRecords.holding(category: .cash, name: "현금", quantity: 100)
        try await repository.save(holding)

        try await repository.delete(id: holding.id)

        #expect(try await repository.fetch(id: holding.id) == nil)
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test("없는 식별자를 지워도 실패하지 않는다")
    func ignoresMissingIdentifier() async throws {
        let repository = try makeRepository()

        try await repository.delete(id: UUID())

        #expect(try await repository.fetchAll().isEmpty)
    }
}
