//
//  MarketDataRepositoryTests.swift
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

/// 시간을 직접 감아 캐시 만료를 재현한다.
private final class TestClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 0))

    /// `Mutex` 는 non-copyable 이라 클로저로 캡처할 수 없다. self 를 통해 빌려 쓴다.
    var now: @Sendable () -> Date {
        { self.current.withLock { $0 } }
    }

    func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}

/// 토큰 발급을 타지 않는 인증기. 이 스위트의 관심사는 라우팅과 캐시다.
private struct FixedAuthorizer: RequestAuthorizing {
    func authorize(_ request: URLRequest) async throws -> URLRequest {
        var authorized = request
        authorized.setValue("Bearer token", forHTTPHeaderField: "authorization")
        return authorized
    }

    func invalidate() async {}
}

@Suite("MarketDataRepository")
struct MarketDataRepositoryTests {
    private static let tickerJSON = """
    [{"market":"KRW-BTC","trade_price":95000000,"signed_change_rate":0.0213}]
    """

    private static let domesticJSON = """
    {"rt_cd":"0","msg1":"정상처리 되었습니다.","output":{"stck_prpr":"70800","prdy_ctrt":"1.28"}}
    """

    private static let overseasJSON = """
    {"rt_cd":"0","msg1":"정상처리 되었습니다.","output":{"last":"228.52","rate":"-0.41"}}
    """

    private func makeRepository(
        cache: QuoteCache,
        isKoreaInvestmentConfigured: Bool = true,
        handler: @escaping StubURLProtocol.Handler
    ) -> (MarketDataRepository, URLSession) {
        let session = StubURLProtocol.makeSession(handler: handler)
        let koreaInvestment = isKoreaInvestmentConfigured
            ? KISClient(
                session: session,
                authorizer: FixedAuthorizer(),
                requestInterval: 0
            )
            : nil

        let repository = MarketDataRepository(
            upbit: UpbitClient(session: session),
            koreaInvestment: koreaInvestment,
            cache: cache
        )
        return (repository, session)
    }

    /// 업비트와 KIS 요청을 호스트로 갈라 각자의 픽스처를 돌려준다.
    private func routedResponse(for request: URLRequest) -> StubResponse {
        guard let host = request.url?.host() else { return .json("{}", statusCode: 500) }

        if host.contains("upbit") { return .json(Self.tickerJSON) }
        guard let path = request.url?.path() else { return .json("{}", statusCode: 500) }

        return path.contains("overseas")
            ? .json(Self.overseasJSON)
            : .json(Self.domesticJSON)
    }

    @Test("업비트 마켓의 현재가를 조회한다")
    func fetchesUpbitPrice() async throws {
        let (repository, session) = makeRepository(cache: QuoteCache()) { _ in
            .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await repository.currentPrice(symbol: "KRW-BTC")

        #expect(price == .krw(95_000_000))
    }

    @Test("국내 종목코드는 KIS 국내 시세로 간다")
    func routesDomesticCodeToKoreaInvestment() async throws {
        let requestedPath = Mutex<String?>(nil)
        let (repository, session) = makeRepository(cache: QuoteCache()) { request in
            requestedPath.withLock { $0 = request.url?.path() }
            return .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await repository.currentPrice(symbol: "005930")

        #expect(price == .krw(70_800))
        #expect(requestedPath.withLock { $0 } == "/uapi/domestic-stock/v1/quotations/inquire-price")
    }

    @Test("해외 티커는 KIS 해외 시세로 가고 달러로 돌아온다")
    func routesOverseasTickerToKoreaInvestment() async throws {
        let (repository, session) = makeRepository(cache: QuoteCache()) { request in
            self.routedResponse(for: request)
        }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await repository.currentPrice(symbol: "NAS:AAPL")

        #expect(price == .usd(Decimal(string: "228.52")!))
    }

    @Test("업비트와 KIS 를 섞어 조회해도 한 번에 합쳐 돌려준다")
    func mergesUpbitAndKoreaInvestment() async throws {
        let (repository, session) = makeRepository(cache: QuoteCache()) { request in
            self.routedResponse(for: request)
        }
        defer { StubURLProtocol.tearDown(session) }

        let quotes = try await repository.currentQuotes(
            symbols: ["KRW-BTC", "005930", "NAS:AAPL"]
        )

        #expect(quotes.count == 3)
        #expect(quotes["KRW-BTC"]?.price == .krw(95_000_000))
        #expect(quotes["005930"]?.price == .krw(70_800))
        #expect(quotes["NAS:AAPL"]?.price == .usd(Decimal(string: "228.52")!))
    }

    @Test("KIS 가 막혀도 업비트 결과는 그대로 살린다")
    func keepsUpbitResultWhenKoreaInvestmentFails() async throws {
        let (repository, session) = makeRepository(cache: QuoteCache()) { request in
            guard request.url?.host()?.contains("upbit") == true else {
                return .json(#"{"msg1":"서비스 점검 중입니다."}"#, statusCode: 500)
            }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let quotes = try await repository.currentQuotes(symbols: ["KRW-BTC", "005930"])

        #expect(quotes["KRW-BTC"]?.price == .krw(95_000_000))
        #expect(quotes["005930"] == nil)
    }

    @Test("유효한 캐시가 있으면 네트워크를 타지 않는다")
    func servesFromCache() async throws {
        let requestCount = Mutex(0)
        let (repository, session) = makeRepository(cache: QuoteCache(timeToLive: 900)) { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = try await repository.currentPrice(symbol: "KRW-BTC")
        _ = try await repository.currentPrice(symbol: "KRW-BTC")

        #expect(requestCount.withLock { $0 } == 1)
    }

    @Test("갱신에 실패하면 마지막 캐시값으로 버틴다")
    func fallsBackToStaleValue() async throws {
        let clock = TestClock()
        let shouldFail = Mutex(false)
        let (repository, session) = makeRepository(
            cache: QuoteCache(timeToLive: 900, now: clock.now)
        ) { _ in
            if shouldFail.withLock({ $0 }) {
                return .json(#"{"error":{"message":"요청 제한"}}"#, statusCode: 429)
            }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = try await repository.currentPrice(symbol: "KRW-BTC")

        // 캐시를 만료시키고 서버를 죽인다 (마지막 캐시값 사용 + 갱신 실패 배지).
        clock.advance(by: 901)
        shouldFail.withLock { $0 = true }

        #expect(try await repository.currentPrice(symbol: "KRW-BTC") == .krw(95_000_000))
    }

    @Test("KIS 조회가 실패해도 마지막 캐시값으로 버틴다")
    func fallsBackToStaleKoreaInvestmentValue() async throws {
        let clock = TestClock()
        let shouldFail = Mutex(false)
        let (repository, session) = makeRepository(
            cache: QuoteCache(timeToLive: 900, now: clock.now)
        ) { _ in
            if shouldFail.withLock({ $0 }) {
                return .json(#"{"msg1":"서비스 점검 중입니다."}"#, statusCode: 500)
            }
            return .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = try await repository.currentPrice(symbol: "005930")

        clock.advance(by: 901)
        shouldFail.withLock { $0 = true }

        #expect(try await repository.currentPrice(symbol: "005930") == .krw(70_800))
    }

    @Test("일부 종목만 실패하면 그 종목에만 stale 표시가 붙는다")
    func marksOnlyFailedSymbolsStale() async throws {
        let clock = TestClock()
        let shouldKoreaInvestmentFail = Mutex(false)
        let (repository, session) = makeRepository(
            cache: QuoteCache(timeToLive: 900, now: clock.now)
        ) { request in
            if request.url?.host()?.contains("upbit") == true { return .json(Self.tickerJSON) }
            guard shouldKoreaInvestmentFail.withLock({ $0 }) else {
                return .json(Self.domesticJSON)
            }
            return .json(#"{"msg1":"서비스 점검 중입니다."}"#, statusCode: 500)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = try await repository.currentQuotes(symbols: ["KRW-BTC", "005930"])

        clock.advance(by: 901)
        shouldKoreaInvestmentFail.withLock { $0 = true }

        let quotes = try await repository.currentQuotes(symbols: ["KRW-BTC", "005930"])

        #expect(quotes["KRW-BTC"]?.isStale == false)
        #expect(quotes["005930"]?.isStale == true)
        #expect(quotes["005930"]?.price == .krw(70_800))
    }

    @Test("캐시도 없이 갱신에 실패하면 에러를 올린다")
    func propagatesErrorWithoutCache() async throws {
        let (repository, session) = makeRepository(cache: QuoteCache()) { _ in
            .json(#"{"error":{"message":"요청 제한"}}"#, statusCode: 429)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.self) {
            try await repository.currentPrice(symbol: "KRW-BTC")
        }
    }

    @Test("KIS 앱키가 없으면 주식 조회는 설정 안내로 막는다")
    func requiresCredentialsForKoreaInvestment() async throws {
        let (repository, session) = makeRepository(
            cache: QuoteCache(),
            isKoreaInvestmentConfigured: false
        ) { _ in
            .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(
            throws: AppError.validation("주식·ETF 시세를 보려면 KIS 앱키를 설정해 주세요.")
        ) {
            try await repository.currentPrice(symbol: "005930")
        }
    }

    @Test("KIS 앱키가 없어도 코인 시세는 그대로 동작한다")
    func servesUpbitWithoutCredentials() async throws {
        let (repository, session) = makeRepository(
            cache: QuoteCache(),
            isKoreaInvestmentConfigured: false
        ) { _ in
            .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(try await repository.currentPrice(symbol: "KRW-BTC") == .krw(95_000_000))
    }

    @Test("배치 조회는 캐시 히트와 네트워크 결과를 합친다")
    func mergesCachedAndFetched() async throws {
        let cache = QuoteCache(timeToLive: 900)
        await cache.store(.krw(5_000_000), for: "KRW-ETH")

        let (repository, session) = makeRepository(cache: cache) { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first?.value
            // 캐시에 있는 KRW-ETH 는 요청에서 빠져야 한다.
            #expect(query == "KRW-BTC")
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let quotes = try await repository.currentQuotes(symbols: ["KRW-BTC", "KRW-ETH"])

        #expect(quotes["KRW-BTC"]?.price == .krw(95_000_000))
        #expect(quotes["KRW-ETH"]?.price == .krw(5_000_000))
    }

    @Test("빈 목록은 네트워크를 타지 않는다")
    func skipsNetworkForEmptySymbols() async throws {
        let requestCount = Mutex(0)
        let (repository, session) = makeRepository(cache: QuoteCache()) { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(try await repository.currentQuotes(symbols: []).isEmpty)
        #expect(requestCount.withLock { $0 } == 0)
    }
}
