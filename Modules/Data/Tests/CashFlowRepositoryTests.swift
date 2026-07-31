//
//  CashFlowRepositoryTests.swift
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

@Suite("CashFlowRepository")
struct CashFlowRepositoryTests {
    private func makeRepository() throws -> CashFlowRepository {
        CashFlowRepository(modelContainer: try HannunModelContainer.make(inMemory: true))
    }

    @Test("입출금을 저장하고 다시 읽는다")
    func savesAndFetches() async throws {
        let repository = try makeRepository()
        let event = SampleRecords.cashFlow(
            occurredOn: SampleRecords.day(2026, 3, 1),
            amount: 1_000_000,
            kind: .deposit,
            memo: "월급"
        )

        try await repository.save(event)

        let stored = try #require(await repository.fetchAll().first)
        #expect(stored.amount == 1_000_000)
        #expect(stored.kind == .deposit)
        #expect(stored.memo == "월급")
        #expect(stored.signedAmount == 1_000_000)
    }

    @Test("출금은 부호가 반대로 읽힌다")
    func keepsWithdrawalSign() async throws {
        let repository = try makeRepository()
        try await repository.save(
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 3, 1),
                amount: 500_000,
                kind: .withdrawal
            )
        )

        #expect(try await repository.fetchAll().first?.signedAmount == -500_000)
    }

    @Test("구간 조회는 경계를 포함한다")
    func fetchesInclusiveRange() async throws {
        let repository = try makeRepository()
        for day in [1, 15, 31] {
            try await repository.save(
                SampleRecords.cashFlow(
                    occurredOn: SampleRecords.day(2026, 3, day),
                    amount: 100_000,
                    kind: .deposit
                )
            )
        }

        let events = try await repository.fetch(
            from: SampleRecords.day(2026, 3, 1),
            to: SampleRecords.day(2026, 3, 15)
        )

        #expect(events.count == 2)
        #expect(events.map(\.occurredOn) == [
            SampleRecords.day(2026, 3, 1),
            SampleRecords.day(2026, 3, 15),
        ])
    }

    @Test("삭제한 입출금은 조회되지 않는다")
    func deletes() async throws {
        let repository = try makeRepository()
        let event = SampleRecords.cashFlow(
            occurredOn: SampleRecords.day(2026, 3, 1),
            amount: 100_000,
            kind: .deposit
        )
        try await repository.save(event)

        try await repository.delete(id: event.id)

        #expect(try await repository.fetchAll().isEmpty)
    }
}
