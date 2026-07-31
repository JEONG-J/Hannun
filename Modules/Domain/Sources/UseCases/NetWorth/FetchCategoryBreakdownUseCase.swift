//
//  FetchCategoryBreakdownUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 자산군 하나의 소계와 비중.
public struct CategoryBreakdown: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let category: AssetCategory
    public let amount: Money

    /// 0...1 비중. 총자산이 0 이면 0.
    public let weight: Decimal

    public var id: AssetCategory { category }

    // MARK: - Function

    public init(category: AssetCategory, amount: Money, weight: Decimal) {
        self.category = category
        self.amount = amount
        self.weight = weight
    }
}

/// 자산군별 소계와 비중을 계산한다. 파이차트와 소계 리스트가 같은 결과를 쓴다.
public protocol FetchCategoryBreakdownUseCaseProtocol: Sendable {
    /// 카테고리 5종을 `AssetCategory.allCases` 순서로 모두 돌려준다.
    /// 보유가 없는 카테고리는 금액 0 이며, 숨길지 여부는 화면이 판단한다.
    func execute(
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> [CategoryBreakdown]
}

public struct FetchCategoryBreakdownUseCase: FetchCategoryBreakdownUseCaseProtocol {
    // MARK: - Property

    private let fetchNetWorthUseCase: any FetchNetWorthUseCaseProtocol

    // MARK: - Function

    public init(fetchNetWorthUseCase: any FetchNetWorthUseCaseProtocol) {
        self.fetchNetWorthUseCase = fetchNetWorthUseCase
    }

    public func execute(
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> [CategoryBreakdown] {
        let netWorth = try await fetchNetWorthUseCase.execute(
            baseCurrency: baseCurrency,
            exchangeRate: exchangeRate
        )
        let total = netWorth.total.amount

        return AssetCategory.allCases.map { category in
            let subtotal = netWorth.subtotal(for: category)
            return CategoryBreakdown(
                category: category,
                amount: subtotal,
                weight: total > 0 ? subtotal.amount / total : 0
            )
        }
    }
}
