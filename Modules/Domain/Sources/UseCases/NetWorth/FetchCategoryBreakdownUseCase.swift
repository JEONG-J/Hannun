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

    /// 0...1 비중. 분모는 부채를 뺀 총자산이라 자산군 비중의 합이 정확히 1 이 된다.
    /// 부채는 0 — 자산군 100% 옆에 "부채 34%" 를 같은 열에 쓰면 한 화면이 134% 로 읽힌다.
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
    /// 카테고리 6종을 `AssetCategory.allCases` 순서로 모두 돌려준다.
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
        // `netWorth.total` 은 자산 − 부채라 이걸 분모로 쓰면 자산군 비중 합이 100% 를 넘는다.
        let assetTotal = AssetCategory.allCases
            .filter { !$0.isLiability }
            .reduce(Decimal.zero) { $0 + netWorth.subtotal(for: $1).amount }

        return AssetCategory.allCases.map { category in
            let subtotal = netWorth.subtotal(for: category)
            let isWeighted = !category.isLiability && assetTotal > 0
            return CategoryBreakdown(
                category: category,
                amount: subtotal,
                weight: isWeighted ? subtotal.amount / assetTotal : 0
            )
        }
    }
}
