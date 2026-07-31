//
//  FetchNetWorthUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 기준 통화로 환산한 총자산과 그 근거가 된 종목별 평가.
public struct NetWorth: Equatable, Sendable {
    // MARK: - Property

    public let total: Money
    public let valuations: [HoldingValuation]

    // MARK: - Function

    public init(total: Money, valuations: [HoldingValuation]) {
        self.total = total
        self.valuations = valuations
    }

    public func subtotal(for category: AssetCategory) -> Money {
        let amount = valuations
            .filter { $0.holding.category == category }
            .reduce(Decimal.zero) { $0 + $1.marketValue.amount }
        return Money(amount: amount, currency: total.currency)
    }

    /// 스냅샷에 그대로 실을 수 있는 카테고리 소계. 카테고리 5종을 모두 포함한다.
    public var categorySubtotals: [CategorySubtotal] {
        AssetCategory.allCases.map {
            CategorySubtotal(category: $0, amount: subtotal(for: $0).amount)
        }
    }
}

/// 전체 보유 자산의 합산 가치를 계산한다.
public protocol FetchNetWorthUseCaseProtocol: Sendable {
    func execute(baseCurrency: Currency, exchangeRate: ExchangeRate) async throws -> NetWorth
}

public struct FetchNetWorthUseCase: FetchNetWorthUseCaseProtocol {
    // MARK: - Property

    private let fetchHoldingsUseCase: any FetchHoldingsUseCaseProtocol

    // MARK: - Function

    public init(fetchHoldingsUseCase: any FetchHoldingsUseCaseProtocol) {
        self.fetchHoldingsUseCase = fetchHoldingsUseCase
    }

    public func execute(
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> NetWorth {
        let valuations = try await fetchHoldingsUseCase.execute(
            category: nil,
            baseCurrency: baseCurrency,
            exchangeRate: exchangeRate
        )
        let total = valuations.reduce(Decimal.zero) { $0 + $1.marketValue.amount }

        return NetWorth(
            total: Money(amount: total, currency: baseCurrency),
            valuations: valuations
        )
    }
}
