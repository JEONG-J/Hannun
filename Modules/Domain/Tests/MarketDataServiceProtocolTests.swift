//
//  MarketDataServiceProtocolTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import Testing
@testable import HannunDomain

/// Domain 이 네트워크 구현 없이도 테스트 가능한지 확인하는 자리 표시자 (봉인 규칙).
private struct StubMarketDataService: MarketDataServiceProtocol {
    let prices: [String: Money]

    func currentPrice(symbol: String) async throws -> Money {
        guard let price = prices[symbol] else {
            throw AppError.validation("알 수 없는 종목: \(symbol)")
        }
        return price
    }

    func currentPrices(symbols: [String]) async throws -> [String: Money] {
        prices.filter { symbols.contains($0.key) }
    }
}

@Suite("MarketDataServiceProtocol")
struct MarketDataServiceProtocolTests {
    private let service = StubMarketDataService(
        prices: ["005930": .krw(70_000), "KRW-BTC": .krw(95_000_000)]
    )

    @Test("스텁 구현으로 프로토콜을 만족한다")
    func stubConforms() async throws {
        let price = try await service.currentPrice(symbol: "005930")
        #expect(price == .krw(70_000))
    }

    @Test("조회하지 못한 심볼은 결과에서 빠진다")
    func batchOmitsUnknownSymbols() async throws {
        let prices = try await service.currentPrices(symbols: ["005930", "없는종목"])

        #expect(prices.count == 1)
        #expect(prices["005930"] == .krw(70_000))
        #expect(prices["없는종목"] == nil)
    }
}
