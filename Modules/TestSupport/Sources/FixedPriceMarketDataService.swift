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
/// `failure` 를 주면 시세 조회가 실패하는 상황(수동 입력가 대체 경로)을, `staleSymbols` 를
/// 주면 일부 종목만 캐시값으로 버티는 상황을 재현할 수 있다.
public struct FixedPriceMarketDataService: MarketDataServiceProtocol {
    // MARK: - Property

    private let prices: [String: Money]
    private let staleSymbols: Set<String>
    private let asOf: Date
    private let failure: AppError?

    // MARK: - Function

    public init(
        prices: [String: Money] = [:],
        staleSymbols: Set<String> = [],
        asOf: Date = Date(),
        failure: AppError? = nil
    ) {
        self.prices = prices
        self.staleSymbols = staleSymbols
        self.asOf = asOf
        self.failure = failure
    }

    public func currentPrice(symbol: String) async throws -> Money {
        if let failure { throw failure }

        guard let price = prices[symbol] else {
            throw AppError.network("시세를 찾을 수 없어요. (\(symbol))")
        }
        return price
    }

    public func currentQuotes(symbols: [String]) async throws -> [String: Quote] {
        if let failure { throw failure }

        var quotes: [String: Quote] = [:]

        for symbol in symbols {
            guard let price = prices[symbol] else { continue }
            quotes[symbol] = Quote(
                price: price,
                asOf: asOf,
                isStale: staleSymbols.contains(symbol)
            )
        }
        return quotes
    }
}
