//
//  FixedPriceMarketDataService.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// 시세를 고정값으로 돌려주는 `MarketDataServiceProtocol` 대역.
///
/// `failure` 를 주면 시세 조회가 실패하는 상황(수동 입력가 대체 경로)을 재현할 수 있다.
public struct FixedPriceMarketDataService: MarketDataServiceProtocol {
    // MARK: - Property

    private let prices: [String: Money]
    private let failure: AppError?

    // MARK: - Function

    public init(prices: [String: Money] = [:], failure: AppError? = nil) {
        self.prices = prices
        self.failure = failure
    }

    public func currentPrice(symbol: String) async throws -> Money {
        if let failure { throw failure }

        guard let price = prices[symbol] else {
            throw AppError.network("시세를 찾을 수 없어요. (\(symbol))")
        }
        return price
    }

    public func currentPrices(symbols: [String]) async throws -> [String: Money] {
        if let failure { throw failure }

        return prices.filter { symbols.contains($0.key) }
    }
}
