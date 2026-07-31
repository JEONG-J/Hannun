import Foundation
import HannunCore
import Synchronization
import Testing
@testable import HannunData

/// 시간을 직접 감아 TTL 을 검증한다. sleep 없이 만료를 재현하려는 목적이다.
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

@Suite("QuoteCache")
struct QuoteCacheTests {
    @Test("저장한 값을 유효 기간 안에서는 그대로 돌려준다")
    func returnsFreshValue() async {
        let cache = QuoteCache(timeToLive: 60, now: TestClock().now)
        await cache.store(.krw(95_000_000), for: "KRW-BTC")

        #expect(await cache.value(for: "KRW-BTC") == .krw(95_000_000))
    }

    @Test("유효 기간이 지나면 nil 을 돌려준다")
    func expiresAfterTimeToLive() async {
        let clock = TestClock()
        let cache = QuoteCache(timeToLive: 60, now: clock.now)
        await cache.store(.krw(95_000_000), for: "KRW-BTC")

        clock.advance(by: 61)

        #expect(await cache.value(for: "KRW-BTC") == nil)
    }

    @Test("만료된 뒤에도 마지막 값은 staleValue 로 남는다")
    func keepsStaleValueAfterExpiry() async {
        let clock = TestClock()
        let cache = QuoteCache(timeToLive: 60, now: clock.now)
        await cache.store(.krw(95_000_000), for: "KRW-BTC")

        clock.advance(by: 61)
        _ = await cache.value(for: "KRW-BTC")

        // value(for:) 가 만료 항목을 지우더라도 폴백용 값은 살아 있어야 한다 (§8).
        #expect(await cache.staleValue(for: "KRW-BTC") == .krw(95_000_000))
    }

    @Test("저장한 적 없는 키는 nil 이다")
    func missesUnknownKey() async {
        let cache = QuoteCache(timeToLive: 60, now: TestClock().now)

        #expect(await cache.value(for: "KRW-DOGE") == nil)
        #expect(await cache.staleValue(for: "KRW-DOGE") == nil)
    }

    @Test("배치 저장은 모든 항목을 같은 시각으로 기록한다")
    func storesBatch() async {
        let cache = QuoteCache(timeToLive: 60, now: TestClock().now)
        await cache.store(["KRW-BTC": .krw(95_000_000), "KRW-ETH": .krw(5_000_000)])

        #expect(await cache.value(for: "KRW-BTC") == .krw(95_000_000))
        #expect(await cache.value(for: "KRW-ETH") == .krw(5_000_000))
    }
}
