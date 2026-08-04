//
//  PortfolioTestFactory.swift
//  PortfolioFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import HannunTestSupport
@testable import PortfolioFeature

/// 실패를 흉내 낼 수 있는 `HoldingRepositoryProtocol` 대역.
///
/// `successCount` 만큼만 조회에 성공하고 그 뒤로는 던진다 — 첫 로딩은 되지만 갱신은 실패하는
/// 상황을 재현하려고 쓴다.
actor FlakyHoldingRepository: HoldingRepositoryProtocol {

    // MARK: - Property

    private let records: [HoldingRecord]
    private var remainingSuccesses: Int

    // MARK: - Function

    init(_ records: [HoldingRecord] = [], successCount: Int = 0) {
        self.records = records
        remainingSuccesses = successCount
    }

    func fetchAll() throws -> [HoldingRecord] {
        guard remainingSuccesses > 0 else { throw AppError.persistence(Self.failureMessage) }

        remainingSuccesses -= 1
        return records
    }

    func fetch(category: AssetCategory) throws -> [HoldingRecord] {
        try fetchAll().filter { $0.category == category }
    }

    func fetch(id: UUID) throws -> HoldingRecord? {
        try fetchAll().first { $0.id == id }
    }

    func save(_ holding: HoldingRecord) throws {
        throw AppError.persistence(Self.failureMessage)
    }

    func delete(id: UUID) throws {
        throw AppError.persistence(Self.failureMessage)
    }

    static let failureMessage = "저장소를 열지 못했어요."
}

/// 테스트가 공유하는 조립 헬퍼.
enum PortfolioTestFactory {

    // MARK: - Function

    @MainActor
    static func listViewModel(
        repository: any HoldingRepositoryProtocol,
        prices: [String: Money] = [:]
    ) -> PortfolioListViewModel {
        PortfolioListViewModel(
            fetchHoldings: FetchHoldingsUseCase(
                holdingRepository: repository,
                marketDataService: FixedPriceMarketDataService(prices: prices)
            ),
            deleteHolding: DeleteHoldingUseCase(holdingRepository: repository),
            exchangeRateService: FixedExchangeRateService(),
            errorHandler: ErrorHandler()
        )
    }

    @MainActor
    static func holdingEditorViewModel(
        repository: any HoldingRepositoryProtocol,
        mode: HoldingEditorMode
    ) -> HoldingEditorViewModel {
        HoldingEditorViewModel(
            saveHolding: SaveHoldingUseCase(holdingRepository: repository),
            errorHandler: ErrorHandler(),
            mode: mode
        )
    }

    @MainActor
    static func cashFlowListViewModel(
        repository: any CashFlowRepositoryProtocol
    ) -> CashFlowListViewModel {
        CashFlowListViewModel(
            manageCashFlow: ManageCashFlowUseCase(cashFlowRepository: repository),
            errorHandler: ErrorHandler(),
            calendar: SampleRecords.utcCalendar
        )
    }

    @MainActor
    static func cashFlowEditorViewModel(
        repository: any CashFlowRepositoryProtocol,
        mode: CashFlowEditorMode
    ) -> CashFlowEditorViewModel {
        CashFlowEditorViewModel(
            manageCashFlow: ManageCashFlowUseCase(cashFlowRepository: repository),
            errorHandler: ErrorHandler(),
            mode: mode,
            now: SampleRecords.day(2026, 7, 24)
        )
    }
}
