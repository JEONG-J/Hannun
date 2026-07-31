//
//  UpbitClientTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Synchronization
import Testing
@testable import HannunData

@Suite("UpbitClient")
struct UpbitClientTests {
    /// 업비트 `GET /v1/ticker` 실제 응답 모양에서 쓰는 필드만 남긴 것.
    private static let tickerJSON = """
    [
      {
        "market": "KRW-BTC",
        "trade_price": 95000000,
        "signed_change_rate": 0.0213,
        "trade_timestamp": 1753843200000
      },
      {
        "market": "KRW-ETH",
        "trade_price": 5123456.7,
        "signed_change_rate": -0.0104,
        "trade_timestamp": 1753843200000
      }
    ]
    """

    @Test("여러 마켓을 한 번에 조회한다")
    func fetchesMultipleMarkets() async throws {
        let session = StubURLProtocol.makeSession { _ in .json(Self.tickerJSON) }
        defer { StubURLProtocol.tearDown(session) }

        let prices = try await UpbitClient(session: session)
            .prices(markets: ["KRW-BTC", "KRW-ETH"])

        #expect(prices.count == 2)
        #expect(prices["KRW-BTC"] == .krw(95_000_000))
        #expect(prices["KRW-ETH"] == .krw(Decimal(string: "5123456.7")!))
    }

    @Test("마켓 목록을 콤마로 이어 한 번만 요청한다")
    func sendsSingleBatchedRequest() async throws {
        let requestedURLs = Mutex<[URL]>([])
        let session = StubURLProtocol.makeSession { request in
            if let url = request.url {
                requestedURLs.withLock { $0.append(url) }
            }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = try await UpbitClient(session: session).prices(markets: ["KRW-BTC", "KRW-ETH"])

        let urls = requestedURLs.withLock { $0 }
        #expect(urls.count == 1)

        let url = try #require(urls.first)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "api.upbit.com")
        #expect(components.path == "/v1/ticker")
        #expect(components.queryItems?.first?.value == "KRW-BTC,KRW-ETH")
    }

    @Test("소수점 가격이 부동소수 오차 없이 그대로 들어온다")
    func preservesDecimalPrecision() async throws {
        let json = """
        [{"market":"KRW-XRP","trade_price":0.1234,"signed_change_rate":0.0}]
        """
        let session = StubURLProtocol.makeSession { _ in .json(json) }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await UpbitClient(session: session).price(market: "KRW-XRP")

        // Decimal 을 JSON 숫자에서 바로 디코딩하면 0.12339999999999999 가 된다.
        #expect(price.amount == Decimal(string: "0.1234")!)
    }

    @Test("빈 목록은 네트워크를 타지 않는다")
    func skipsNetworkForEmptyMarkets() async throws {
        let requestCount = Mutex(0)
        let session = StubURLProtocol.makeSession { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let prices = try await UpbitClient(session: session).prices(markets: [])

        #expect(prices.isEmpty)
        #expect(requestCount.withLock { $0 } == 0)
    }

    @Test("응답에 없는 마켓을 단건 조회하면 validation 에러다")
    func throwsForMissingMarket() async throws {
        let session = StubURLProtocol.makeSession { _ in .json("[]") }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.validation("업비트에서 조회할 수 없는 마켓입니다: KRW-DOGE")) {
            try await UpbitClient(session: session).price(market: "KRW-DOGE")
        }
    }
}
