//
//  HoldingEditorViewModelTests.swift
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
@Suite("종목 추가·수정")
struct HoldingEditorViewModelTests {

    // MARK: - Property

    private let existing = SampleRecords.holding(
        category: .domesticStock,
        name: "삼성전자",
        ticker: "005930",
        quantity: 10,
        averagePrice: 70_000
    )

    // MARK: - Function

    @Test("추가는 자산유형부터 시작한다")
    func createStartsAtAssetType() {
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: InMemoryHoldingRepository(),
            mode: .create
        )

        #expect(viewModel.step == .assetType)
        #expect(viewModel.title == "종목 추가 (1/3)")
        #expect(viewModel.canProceed)
        #expect(!viewModel.canGoBack)
        #expect(!viewModel.isLastStep)
    }

    @Test("수정은 수량·평단가 단계만 연다")
    func editOpensPositionOnly() {
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: InMemoryHoldingRepository([existing]),
            mode: .edit(existing)
        )

        #expect(viewModel.step == .position)
        #expect(viewModel.title == "보유 내역 수정")
        #expect(viewModel.isEditing)
        #expect(!viewModel.canGoBack)
        #expect(viewModel.quantityText == "10")
        #expect(viewModel.averagePriceText == "70000")
    }

    @Test("종목명과 티커가 있어야 다음 단계로 넘어간다")
    func identityRequiresNameAndTicker() {
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: InMemoryHoldingRepository(),
            mode: .create
        )

        viewModel.advance()
        #expect(viewModel.step == .identity)
        #expect(!viewModel.canProceed)

        viewModel.name = "삼성전자"
        #expect(!viewModel.canProceed)

        viewModel.ticker = "005930"
        #expect(viewModel.canProceed)

        viewModel.advance()
        #expect(viewModel.step == .position)
        #expect(viewModel.isLastStep)
    }

    @Test("현금은 티커 없이도 넘어간다")
    func cashSkipsTicker() {
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: InMemoryHoldingRepository(),
            mode: .create
        )

        viewModel.selectCategory(.cash)
        viewModel.advance()
        viewModel.name = "생활비 통장"

        #expect(viewModel.isCash)
        #expect(viewModel.canProceed)
        #expect(viewModel.quantityFieldTitle == "잔액")
        #expect(viewModel.quantityUnit == "KRW")
    }

    @Test("이전 단계로 되돌아갈 수 있다")
    func retreatsToPreviousStep() {
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: InMemoryHoldingRepository(),
            mode: .create
        )

        viewModel.advance()
        viewModel.retreat()

        #expect(viewModel.step == .assetType)
    }

    @Test("수량과 평단가를 채워야 저장 버튼이 열린다")
    func positionRequiresQuantityAndAveragePrice() {
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: InMemoryHoldingRepository([existing]),
            mode: .edit(existing)
        )

        viewModel.quantityText = ""
        #expect(!viewModel.canProceed)

        viewModel.quantityText = "12"
        viewModel.averagePriceText = ""
        #expect(!viewModel.canProceed)

        viewModel.averagePriceText = "71,000"
        #expect(viewModel.canProceed)
    }

    @Test("추가한 종목이 저장소에 남는다")
    func savesNewHolding() async throws {
        let repository = InMemoryHoldingRepository()
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.selectCategory(.overseasStock)
        viewModel.name = "Apple"
        viewModel.ticker = "AAPL"
        viewModel.currency = .usd
        viewModel.quantityText = "5"
        viewModel.averagePriceText = "150"
        await viewModel.save()

        let saved = try #require(await repository.fetchAll().first)

        #expect(viewModel.didSave)
        #expect(saved.name == "Apple")
        #expect(saved.ticker == "AAPL")
        #expect(saved.currency == .usd)
        #expect(saved.quantity == 5)
        #expect(saved.averagePrice == 150)
    }

    @Test("수정은 같은 종목의 수량과 평단가만 바꾼다")
    func updatesExistingHolding() async throws {
        let repository = InMemoryHoldingRepository([existing])
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: repository,
            mode: .edit(existing)
        )

        viewModel.quantityText = "12"
        viewModel.averagePriceText = "72500"
        await viewModel.save()

        let all = await repository.fetchAll()
        let saved = try #require(all.first)

        #expect(all.count == 1)
        #expect(saved.id == existing.id)
        #expect(saved.quantity == 12)
        #expect(saved.averagePrice == 72_500)
        #expect(saved.createdAt == existing.createdAt)
    }

    @Test("현금은 평단가를 저장하지 않는다")
    func cashDropsAveragePrice() async throws {
        let repository = InMemoryHoldingRepository()
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.selectCategory(.cash)
        viewModel.name = "생활비 통장"
        viewModel.averagePriceText = "1000"
        viewModel.quantityText = "1,000,000"
        await viewModel.save()

        let saved = try #require(await repository.fetchAll().first)

        #expect(saved.quantity == 1_000_000)
        #expect(saved.averagePrice == nil)
        #expect(saved.ticker.isEmpty)
    }

    @Test("시세가 없는 종목은 현재가를 직접 넣어 둔다")
    func keepsManualPrice() async throws {
        let repository = InMemoryHoldingRepository()
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.selectCategory(.crypto)
        viewModel.name = "비상장 코인"
        viewModel.ticker = "PRIV"
        viewModel.quantityText = "3"
        viewModel.averagePriceText = "1000"
        viewModel.manualPriceText = "1500"
        viewModel.usesManualPrice = true
        await viewModel.save()

        let saved = try #require(await repository.fetchAll().first)

        #expect(saved.manualPrice == 1_500)
    }

    @Test("수동 입력을 끄면 적어 둔 현재가는 버린다")
    func discardsManualPriceWhenDisabled() async throws {
        let repository = InMemoryHoldingRepository()
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.name = "삼성전자"
        viewModel.ticker = "005930"
        viewModel.quantityText = "10"
        viewModel.averagePriceText = "70000"
        viewModel.manualPriceText = "80000"
        viewModel.usesManualPrice = false
        await viewModel.save()

        let saved = try #require(await repository.fetchAll().first)

        #expect(saved.manualPrice == nil)
    }

    @Test("검증에 걸리면 sheet 안에 문구로 남는다")
    func showsValidationInline() async {
        let repository = InMemoryHoldingRepository()
        let viewModel = PortfolioTestFactory.holdingEditorViewModel(
            repository: repository,
            mode: .create
        )

        viewModel.name = "   "
        viewModel.ticker = "005930"
        viewModel.quantityText = "10"
        viewModel.averagePriceText = "70000"
        await viewModel.save()

        let saved = await repository.fetchAll()

        #expect(!viewModel.didSave)
        #expect(viewModel.validationMessage == "종목명을 입력해 주세요.")
        #expect(saved.isEmpty)
    }
}
