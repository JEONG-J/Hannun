//
//  KISTokenProviderTests.swift
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

/// Keychain 을 타지 않는 저장소. 병렬 테스트에서 서로 덮어쓰지 않도록 인스턴스마다 독립이다.
private actor InMemoryTokenStore: KISTokenStoring {
    private(set) var saveCount = 0
    private(set) var removeCount = 0
    private var token: KISToken?

    init(token: KISToken? = nil) {
        self.token = token
    }

    func load() async -> KISToken? { token }

    func save(_ token: KISToken) async {
        self.token = token
        saveCount += 1
    }

    func removeAll() async {
        token = nil
        removeCount += 1
    }
}

/// 발급 횟수 카운터. `Mutex` 는 non-copyable 이라 인자로 넘길 수 없어 감싼다.
private final class IssueCounter: Sendable {
    private let count = Mutex(0)

    var current: Int { count.withLock { $0 } }

    func increment() -> Int {
        count.withLock { value in
            value += 1
            return value
        }
    }
}

@Suite("KISTokenProvider")
struct KISTokenProviderTests {
    private static let credentials = KISCredentials(appKey: "key", appSecret: "secret")
    private static let issuedAt = Date(timeIntervalSince1970: 1_785_000_000)

    /// 발급 요청 횟수를 세면서 매번 다른 토큰을 돌려준다.
    private func makeIssuingSession(
        counter: IssueCounter,
        delay: TimeInterval = 0
    ) -> URLSession {
        StubURLProtocol.makeSession { _ in
            let issued = counter.increment()
            if delay > 0 { Thread.sleep(forTimeInterval: delay) }

            return .json("""
            {
              "access_token": "issued-\(issued)",
              "token_type": "Bearer",
              "expires_in": 86400,
              "access_token_token_expired": "2026-08-02 09:00:00"
            }
            """)
        }
    }

    private func bearer(from request: URLRequest) -> String? {
        request.value(forHTTPHeaderField: "authorization")
    }

    @Test("첫 요청에 토큰을 발급하고 인증 헤더 3종을 붙인다")
    func issuesTokenAndAppliesHeaders() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: InMemoryTokenStore(),
            session: session
        )
        let authorized = try await provider.authorize(
            URLRequest(url: URL(string: "https://example.com")!)
        )

        #expect(bearer(from: authorized) == "Bearer issued-1")
        #expect(authorized.value(forHTTPHeaderField: "appkey") == "key")
        #expect(authorized.value(forHTTPHeaderField: "appsecret") == "secret")
        #expect(counter.current == 1)
    }

    @Test("유효한 토큰이 있으면 다시 발급하지 않는다")
    func reusesValidToken() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: InMemoryTokenStore(),
            session: session
        )
        let request = URLRequest(url: URL(string: "https://example.com")!)
        _ = try await provider.authorize(request)
        let second = try await provider.authorize(request)

        #expect(bearer(from: second) == "Bearer issued-1")
        #expect(counter.current == 1)
    }

    @Test("동시에 몰린 요청을 발급 1회로 합류시킨다")
    func joinsConcurrentIssueRequests() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter, delay: 0.05)
        defer { StubURLProtocol.tearDown(session) }

        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: InMemoryTokenStore(),
            session: session
        )

        let tokens = await withTaskGroup(of: String?.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let request = URLRequest(url: URL(string: "https://example.com")!)
                    return try? await provider.authorize(request)
                        .value(forHTTPHeaderField: "authorization")
                }
            }

            var collected: [String?] = []
            for await token in group {
                collected.append(token)
            }
            return collected
        }

        #expect(counter.current == 1)
        #expect(tokens.allSatisfy { $0 == "Bearer issued-1" })
    }

    @Test("저장소에 유효한 토큰이 있으면 네트워크를 타지 않는다")
    func restoresTokenFromStore() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let stored = KISToken(
            accessToken: "stored",
            expiresAt: Self.issuedAt.addingTimeInterval(3600)
        )
        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: InMemoryTokenStore(token: stored),
            session: session,
            now: { Self.issuedAt }
        )
        let authorized = try await provider.authorize(
            URLRequest(url: URL(string: "https://example.com")!)
        )

        #expect(bearer(from: authorized) == "Bearer stored")
        #expect(counter.current == 0)
    }

    @Test("만료가 임박한 토큰은 401 을 기다리지 않고 미리 갱신한다")
    func refreshesBeforeExpiry() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let nearlyExpired = KISToken(
            accessToken: "stale",
            expiresAt: Self.issuedAt.addingTimeInterval(30)
        )
        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: InMemoryTokenStore(token: nearlyExpired),
            session: session,
            refreshMargin: 60,
            now: { Self.issuedAt }
        )
        let authorized = try await provider.authorize(
            URLRequest(url: URL(string: "https://example.com")!)
        )

        #expect(bearer(from: authorized) == "Bearer issued-1")
        #expect(counter.current == 1)
    }

    @Test("발급한 토큰을 저장소에 보관한다")
    func persistsIssuedToken() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let store = InMemoryTokenStore()
        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: store,
            session: session
        )
        _ = try await provider.authorize(URLRequest(url: URL(string: "https://example.com")!))

        #expect(await store.saveCount == 1)
        #expect(await store.load()?.accessToken == "issued-1")
    }

    @Test("무효화하면 저장소를 비우고 다음 요청에 다시 발급한다")
    func reissuesAfterInvalidate() async throws {
        let counter = IssueCounter()
        let session = makeIssuingSession(counter: counter)
        defer { StubURLProtocol.tearDown(session) }

        let store = InMemoryTokenStore()
        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: store,
            session: session
        )
        let request = URLRequest(url: URL(string: "https://example.com")!)
        _ = try await provider.authorize(request)

        await provider.invalidate()
        let reissued = try await provider.authorize(request)

        #expect(await store.removeCount == 1)
        #expect(bearer(from: reissued) == "Bearer issued-2")
        #expect(counter.current == 2)
    }

    @Test("발급에 실패하면 에러를 그대로 올린다")
    func propagatesIssueFailure() async throws {
        let session = StubURLProtocol.makeSession { _ in
            .json(#"{"error_description":"앱키가 올바르지 않습니다."}"#, statusCode: 403)
        }
        defer { StubURLProtocol.tearDown(session) }

        let provider = KISTokenProvider(
            credentials: Self.credentials,
            store: InMemoryTokenStore(),
            session: session
        )

        await #expect(throws: AppError.self) {
            try await provider.authorize(URLRequest(url: URL(string: "https://example.com")!))
        }
    }
}
