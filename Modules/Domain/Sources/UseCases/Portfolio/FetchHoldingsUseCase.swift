//
//  FetchHoldingsUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 보유 종목을 현재가로 평가해 돌려준다. 포트폴리오 탭과 순자산 탭이 함께 쓴다.
public protocol FetchHoldingsUseCaseProtocol: Sendable {
    func execute(
        category: AssetCategory?,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> [HoldingValuation]
}

public struct FetchHoldingsUseCase: FetchHoldingsUseCaseProtocol {
    // MARK: - Property

    private let holdingRepository: any HoldingRepositoryProtocol
    private let marketDataService: any MarketDataServiceProtocol

    // MARK: - Function

    public init(
        holdingRepository: any HoldingRepositoryProtocol,
        marketDataService: any MarketDataServiceProtocol
    ) {
        self.holdingRepository = holdingRepository
        self.marketDataService = marketDataService
    }

    public func execute(
        category: AssetCategory?,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> [HoldingValuation] {
        let holdings: [HoldingRecord] = if let category {
            try await holdingRepository.fetch(category: category)
        } else {
            try await holdingRepository.fetchAll()
        }

        let valuator = HoldingValuator(
            baseCurrency: baseCurrency,
            exchangeRate: exchangeRate,
            prices: await prices(for: holdings)
        )
        return holdings.map(valuator.valuation(for:))
    }

    /// 시세 조회 실패를 빈 시세로 흡수한다.
    ///
    /// 수동 입력가·평단가 폴백이 뒤를 받치므로 화면 전체를 실패 상태로 떨어뜨리지 않는다.
    /// 갱신에 실패했다는 사실은 시세 계층의 캐시 신선도가 따로 알린다.
    private func prices(for holdings: [HoldingRecord]) async -> [String: Money] {
        let symbols = Set(
            holdings
                .filter { $0.category != .cash && !$0.ticker.isEmpty }
                .map(\.ticker)
        )
        guard !symbols.isEmpty else { return [:] }

        return (try? await marketDataService.currentPrices(symbols: Array(symbols))) ?? [:]
    }
}
