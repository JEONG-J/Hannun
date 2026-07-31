//
//  ExchangeRateRepositoryTests.swift
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

/// 시간을 직접 감아 환율 캐시의 유효 기간을 검증한다.
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

/// 앱 재실행을 흉내 내려면 저장소가 캐시 인스턴스보다 오래 살아야 한다.
private final class InMemoryExchangeRateStore: ExchangeRateStoring {
    private let stored = Mutex<StoredExchangeRate?>(nil)

    init(_ initial: StoredExchangeRate? = nil) {
        stored.withLock { $0 = initial }
    }

    func load() async -> StoredExchangeRate? {
        stored.withLock { $0 }
    }

    func save(_ rate: StoredExchangeRate) async {
        stored.withLock { $0 = rate }
    }
}

/// 토큰 발급을 타지 않는 인증기. 이 스위트의 관심사는 폴백 순서다.
private struct FixedAuthorizer: RequestAuthorizing {
    func authorize(_ request: URLRequest) async throws -> URLRequest {
        var authorized = request
        authorized.setValue("Bearer token", forHTTPHeaderField: "authorization")
        return authorized
    }

    func invalidate() async {}
}

@Suite("ExchangeRateRepository")
struct ExchangeRateRepositoryTests {
    private static let successJSON = """
    {"rt_cd":"0","msg1":"정상처리 되었습니다.","output1":{"ovrs_nmix_prpr":"1350.40"}}
    """

    private static let failureJSON = #"{"rt_cd":"1","msg1":"서비스 점검 중입니다."}"#

    private static var fetchedRate: ExchangeRate {
        ExchangeRate(krwPerUSD: Decimal(string: "1350.40") ?? .zero)
    }

    private func makeRepository(
        cache: ExchangeRateCache,
        isKoreaInvestmentConfigured: Bool = true,
        handler: @escaping StubURLProtocol.Handler
    ) -> (ExchangeRateRepository, URLSession) {
        let session = StubURLProtocol.makeSession(handler: handler)
        let koreaInvestment = isKoreaInvestmentConfigured
            ? KISClient(session: session, authorizer: FixedAuthorizer())
            : nil

        return (
            ExchangeRateRepository(koreaInvestment: koreaInvestment, cache: cache),
            session
        )
    }

    @Test("KIS 응답의 output1 에서 환율을 읽는다")
    func fetchesRateFromKoreaInvestment() async {
        let (repository, session) = makeRepository(
            cache: ExchangeRateCache(storage: InMemoryExchangeRateStore())
        ) { _ in
            .json(Self.successJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(await repository.currentRate() == Self.fetchedRate)
    }

    @Test("유효 기간 안에는 네트워크를 다시 타지 않는다")
    func servesFromCacheWithinTimeToLive() async {
        let requestCount = Mutex(0)
        let (repository, session) = makeRepository(
            cache: ExchangeRateCache(
                storage: InMemoryExchangeRateStore(),
                timeToLive: 3_600,
                now: TestClock().now
            )
        ) { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.successJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = await repository.currentRate()
        _ = await repository.currentRate()

        #expect(requestCount.withLock { $0 } == 1)
    }

    @Test("갱신에 실패하면 마지막으로 성공한 환율로 버틴다")
    func fallsBackToLastKnownRate() async {
        let clock = TestClock()
        let shouldFail = Mutex(false)
        let (repository, session) = makeRepository(
            cache: ExchangeRateCache(
                storage: InMemoryExchangeRateStore(),
                timeToLive: 3_600,
                now: clock.now
            )
        ) { _ in
            shouldFail.withLock { $0 } ? .json(Self.failureJSON) : .json(Self.successJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = await repository.currentRate()

        clock.advance(by: 3_601)
        shouldFail.withLock { $0 = true }

        #expect(await repository.currentRate() == Self.fetchedRate)
    }

    @Test("앱을 다시 켜도 저장해 둔 환율을 먼저 쓴다")
    func reusesPersistedRateAfterRelaunch() async {
        let storage = InMemoryExchangeRateStore()
        let clock = TestClock()

        let (first, firstSession) = makeRepository(
            cache: ExchangeRateCache(storage: storage, timeToLive: 3_600, now: clock.now)
        ) { _ in
            .json(Self.successJSON)
        }
        _ = await first.currentRate()
        StubURLProtocol.tearDown(firstSession)

        // 캐시 인스턴스를 새로 만들어 콜드 스타트를 흉내 내고, 이번엔 서버를 죽인다.
        clock.advance(by: 3_601)
        let (second, secondSession) = makeRepository(
            cache: ExchangeRateCache(storage: storage, timeToLive: 3_600, now: clock.now)
        ) { _ in
            .json(Self.failureJSON)
        }
        defer { StubURLProtocol.tearDown(secondSession) }

        #expect(await second.currentRate() == Self.fetchedRate)
    }

    @Test("KIS 앱키가 없고 저장된 값도 없으면 씨앗 환율을 쓴다")
    func fallsBackToSeedRate() async {
        let (repository, session) = makeRepository(
            cache: ExchangeRateCache(storage: InMemoryExchangeRateStore()),
            isKoreaInvestmentConfigured: false
        ) { _ in
            .json(Self.successJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(await repository.currentRate() == ExchangeRateRepository.seedRate)
    }

    @Test("응답의 환율이 0 이면 받아들이지 않고 폴백한다")
    func rejectsNonPositiveRate() async {
        let (repository, session) = makeRepository(
            cache: ExchangeRateCache(storage: InMemoryExchangeRateStore())
        ) { _ in
            .json(#"{"rt_cd":"0","msg1":"정상","output1":{"ovrs_nmix_prpr":"0"}}"#)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(await repository.currentRate() == ExchangeRateRepository.seedRate)
    }
}

@Suite("UserDefaultsExchangeRateStore")
struct UserDefaultsExchangeRateStoreTests {
    @Test("저장한 환율을 다시 읽어 온다")
    func roundTripsThroughUserDefaults() async throws {
        let suiteName = "exchange-rate-store-\(UUID().uuidString)"
        let store = UserDefaultsExchangeRateStore(suiteName: suiteName)
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let record = StoredExchangeRate(
            krwPerUSD: Decimal(string: "1350.40") ?? .zero,
            updatedAt: Date(timeIntervalSince1970: 1_785_628_800)
        )
        await store.save(record)

        #expect(await store.load() == record)
    }

    @Test("저장한 적이 없으면 nil 이다")
    func returnsNilWithoutSavedRate() async {
        let suiteName = "exchange-rate-store-\(UUID().uuidString)"
        let store = UserDefaultsExchangeRateStore(suiteName: suiteName)
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        #expect(await store.load() == nil)
    }
}
