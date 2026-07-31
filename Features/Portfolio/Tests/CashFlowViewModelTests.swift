//
//  CashFlowViewModelTests.swift
//  PortfolioFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import HannunTestSupport
import Testing
@testable import PortfolioFeature

@MainActor
@Suite("입출금 기록")
struct CashFlowViewModelTests {

    // MARK: - Property

    private let julyDepositID = UUID()
    private let juneWithdrawalID = UUID()

    private var records: [CashFlowRecord] {
        [
            SampleRecords.cashFlow(
                id: juneWithdrawalID,
                occurredOn: SampleRecords.day(2026, 6, 10),
                amount: 500_000,
                kind: .withdrawal,
                memo: "전세 보증금"
            ),
            SampleRecords.cashFlow(
                id: julyDepositID,
                occurredOn: SampleRecords.day(2026, 7, 24),
                amount: 3_000_000,
                kind: .deposit,
                memo: "월급 이체"
            ),
            SampleRecords.cashFlow(
                occurredOn: SampleRecords.day(2026, 7, 3),
                amount: 1_000_000,
                kind: .deposit,
                memo: "상여금"
            ),
        ]
    }

    // MARK: - Function

    @Test("월별로 묶고 최근 달을 위에 둔다")
    func groupsByMonth() async {
        let viewModel = PortfolioTestFactory.cashFlowListViewModel(
            repository: InMemoryCashFlowRepository(records)
        )

        await viewModel.load()

        let expectedMonths = [SampleRecords.day(2026, 7, 1), SampleRecords.day(2026, 6, 1)]

        #expect(viewModel.sections.map(\.month) == expectedMonths)
        #expect(viewModel.sections.first?.events.count == 2)
        #expect(viewModel.sections.last?.events.count == 1)
    }

    @Test("같은 달 안에서는 최근 기록이 먼저 온다")
    func sortsEventsWithinMonth() async {
        let viewModel = PortfolioTestFactory.cashFlowListViewModel(
            repository: InMemoryCashFlowRepository(records)
        )

        await viewModel.load()

        #expect(viewModel.sections.first?.events.map(\.memo) == ["월급 이체", "상여금"])
    }

    @Test("기록이 없으면 비어 있다고 알린다")
    func reportsEmptyState() async {
        let viewModel = PortfolioTestFactory.cashFlowListViewModel(
            repository: InMemoryCashFlowRepository()
        )

        await viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.sections.isEmpty)
    }

    @Test("삭제 요청만으로는 지워지지 않는다")
    func deleteNeedsConfirmation() async throws {
        let repository = InMemoryCashFlowRepository(records)
        let viewModel = PortfolioTestFactory.cashFlowListViewModel(repository: repository)

        await viewModel.load()
        let target = try #require(viewModel.sections.first?.events.first)
        viewModel.requestDelete(target)
        let remaining = await repository.fetchAll()

        #expect(viewModel.alertPrompt?.title == "입금 기록 삭제")
        #expect(viewModel.alertPrompt?.isDestructive == true)
        #expect(remaining.count == 3)
    }

    @Test("확인한 뒤에는 목록에서 사라진다")
    func deletesAfterConfirmation() async {
        let repository = InMemoryCashFlowRepository(records)
        let viewModel = PortfolioTestFactory.cashFlowListViewModel(repository: repository)

        await viewModel.load()
        await viewModel.delete(id: juneWithdrawalID)

        #expect(viewModel.sections.count == 1)
        #expect(viewModel.sections.first?.events.count == 2)
    }

    @Test("새 기록은 오늘 날짜의 입금으로 시작한다")
    func createStartsWithToday() {
        let viewModel = PortfolioTestFactory.cashFlowEditorViewModel(
            repository: InMemoryCashFlowRepository(),
            mode: .create
        )

        #expect(viewModel.title == "입출금 기록")
        #expect(viewModel.occurredOn == SampleRecords.day(2026, 7, 24))
        #expect(viewModel.kind == .deposit)
        #expect(viewModel.currency == .krw)
        #expect(!viewModel.canSave)
    }

    @Test("금액을 채워야 저장할 수 있다")
    func requiresPositiveAmount() async {
        let repository = InMemoryCashFlowRepository()
        let viewModel = PortfolioTestFactory.cashFlowEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.amountText = "0"
        #expect(!viewModel.canSave)

        await viewModel.save()
        let saved = await repository.fetchAll()

        #expect(!viewModel.didSave)
        #expect(saved.isEmpty)
    }

    @Test("출금은 부호가 음수로 남는다")
    func savesWithdrawalAsNegative() async throws {
        let repository = InMemoryCashFlowRepository()
        let viewModel = PortfolioTestFactory.cashFlowEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.kind = .withdrawal
        viewModel.amountText = "500,000"
        viewModel.memo = " 전세 보증금 "
        await viewModel.save()

        let saved = try #require(await repository.fetchAll().first)

        #expect(viewModel.didSave)
        #expect(saved.amount == 500_000)
        #expect(saved.signedAmount == -500_000)
        #expect(saved.memo == "전세 보증금")
        #expect(saved.occurredOn == SampleRecords.day(2026, 7, 24))
    }

    @Test("수정은 같은 기록을 덮어쓴다")
    func updatesExistingEvent() async throws {
        let repository = InMemoryCashFlowRepository(records)
        let event = try #require(records.first { $0.id == julyDepositID })
        let viewModel = PortfolioTestFactory.cashFlowEditorViewModel(
            repository: repository,
            mode: .edit(event)
        )

        #expect(viewModel.title == "입출금 기록 수정")
        #expect(viewModel.amountText == "3000000")
        #expect(viewModel.canSave)

        viewModel.amountText = "3500000"
        await viewModel.save()

        let all = await repository.fetchAll()
        let saved = try #require(all.first { $0.id == julyDepositID })

        #expect(all.count == 3)
        #expect(saved.amount == 3_500_000)
        #expect(saved.occurredOn == event.occurredOn)
    }
}
