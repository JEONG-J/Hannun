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

@Suite("MarketDataRepository")
struct MarketDataRepositoryTests {
    private static let tickerJSON = """
    [{"market":"KRW-BTC","trade_price":95000000,"signed_change_rate":0.0213}]
    """

    private func makeRepository(
        cache: QuoteCache,
        handler: @escaping StubURLProtocol.Handler
    ) -> (MarketDataRepository, URLSession) {
        let session = StubURLProtocol.makeSession(handler: handler)
        return (MarketDataRepository(upbit: UpbitClient(session: session), cache: cache), session)
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

        // 캐시를 만료시키고 서버를 죽인다 (§8: 마지막 캐시값 사용 + 갱신 실패 배지).
        clock.advance(by: 901)
        shouldFail.withLock { $0 = true }

        #expect(try await repository.currentPrice(symbol: "KRW-BTC") == .krw(95_000_000))
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

    @Test("아직 지원하지 않는 제공자는 validation 에러다")
    func rejectsUnsupportedProvider() async throws {
        let (repository, session) = makeRepository(cache: QuoteCache()) { _ in
            .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.validation("아직 시세를 조회할 수 없는 종목입니다: 005930")) {
            try await repository.currentPrice(symbol: "005930")
        }
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

        let prices = try await repository.currentPrices(symbols: ["KRW-BTC", "KRW-ETH"])

        #expect(prices["KRW-BTC"] == .krw(95_000_000))
        #expect(prices["KRW-ETH"] == .krw(5_000_000))
    }

    @Test("빈 목록은 네트워크를 타지 않는다")
    func skipsNetworkForEmptySymbols() async throws {
        let requestCount = Mutex(0)
        let (repository, session) = makeRepository(cache: QuoteCache()) { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(try await repository.currentPrices(symbols: []).isEmpty)
        #expect(requestCount.withLock { $0 } == 0)
    }
}
