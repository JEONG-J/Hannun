//
//  MarketRepositoriesTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Synchronization
import Testing
@testable import HannunData

/// Keychain 을 타지 않는 토큰 저장소. 병렬 테스트가 서로 덮어쓰지 않도록 인스턴스마다 독립이다.
private actor InMemoryTokenStore: KISTokenStoring {
    private var token: KISToken?

    func load() async -> KISToken? { token }

    func save(_ token: KISToken) async { self.token = token }

    func removeAll() async { token = nil }
}

/// 저장된 환율을 남기지 않는다. UserDefaults 를 쓰면 앞선 테스트가 넣어 둔 값 때문에
/// 환율 조회가 네트워크를 아예 타지 않는다.
private final class EmptyExchangeRateStore: ExchangeRateStoring {
    func load() async -> StoredExchangeRate? { nil }

    func save(_ rate: StoredExchangeRate) async {}
}

/// 토큰 발급 횟수 카운터. `Mutex` 는 non-copyable 이라 인자로 넘길 수 없어 감싼다.
private final class TokenIssueCounter: Sendable {
    private let count = Mutex(0)

    var current: Int { count.withLock { $0 } }

    func increment() {
        count.withLock { $0 += 1 }
    }
}

@Suite("MarketRepositories")
struct MarketRepositoriesTests {
    private static let credentials = KISCredentials(appKey: "key", appSecret: "secret")

    private static let tokenJSON = """
    {
      "access_token": "issued",
      "token_type": "Bearer",
      "expires_in": 86400,
      "access_token_token_expired": "2026-08-02 09:00:00"
    }
    """

    private static let quoteJSON = """
    {"rt_cd":"0","msg1":"정상","output":{"stck_prpr":"70800","prdy_ctrt":"1.28"}}
    """

    private static let exchangeRateJSON = """
    {"rt_cd":"0","msg1":"정상","output1":{"ovrs_nmix_prpr":"1350.40"}}
    """

    /// 발급 요청만 세면서 나머지 경로는 정상 응답으로 흘려보낸다.
    private func makeSession(counter: TokenIssueCounter) -> URLSession {
        StubURLProtocol.makeSession { request in
            guard let path = request.url?.path() else { return .json("{}", statusCode: 500) }

            switch path {
            case "/oauth2/tokenP":
                counter.increment()
                // 두 저장소가 동시에 들어와야 발급이 겹치므로 왕복을 일부러 늦춘다.
                Thread.sleep(forTimeInterval: 0.05)
                return .json(Self.tokenJSON)

            case "/uapi/overseas-price/v1/quotations/inquire-daily-chartprice":
                return .json(Self.exchangeRateJSON)

            default:
                return .json(Self.quoteJSON)
            }
        }
    }

    private func makeRepositories(session: URLSession) -> MarketRepositories {
        MarketRepositories(
            session: session,
            koreaInvestment: KISClient(
                session: session,
                authorizer: KISTokenProvider(
                    credentials: Self.credentials,
                    store: InMemoryTokenStore(),
                    session: session
                )
            ),
            quoteCache: QuoteCache(),
            exchangeRateCache: ExchangeRateCache(storage: EmptyExchangeRateStore())
        )
    }

    /// 저장소마다 클라이언트를 새로 만들면 토큰 발급기도 둘이 되어, 앱을 처음 켜는 순간
    /// 시세와 환율이 각자 토큰을 받아 간다. KIS 는 발급 호출에 빈도 제한을 걸어 둔다.
    @Test("동시에 조회해도 접근토큰은 한 번만 발급된다")
    func sharesAccessTokenBetweenQuoteAndExchangeRate() async throws {
        let counter = TokenIssueCounter()
        let session = makeSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let repositories = makeRepositories(session: session)

        async let price = repositories.marketData.currentPrice(symbol: "005930")
        async let rate = repositories.exchangeRate.currentRate()
        let (fetchedPrice, fetchedRate) = try await (price, rate)

        // 두 값이 응답에서 온 값이어야 각자 실제로 네트워크를 탔다는 뜻이다.
        #expect(fetchedPrice == .krw(70_800))
        #expect(fetchedRate == ExchangeRate(krwPerUSD: Decimal(string: "1350.40") ?? .zero))
        #expect(counter.current == 1)
    }

    @Test("KIS 앱키가 없어도 두 저장소가 만들어진다")
    func buildsWithoutKoreaInvestmentCredentials() async {
        let session = StubURLProtocol.makeSession { _ in .json(Self.quoteJSON) }
        defer { StubURLProtocol.tearDown(session) }

        let repositories = MarketRepositories(
            session: session,
            koreaInvestment: nil,
            quoteCache: QuoteCache(),
            exchangeRateCache: ExchangeRateCache(storage: EmptyExchangeRateStore())
        )

        #expect(await repositories.exchangeRate.currentRate() == ExchangeRateRepository.seedRate)
    }
}
