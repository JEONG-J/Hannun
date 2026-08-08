//
//  KISTokenProvider.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// KIS 접근토큰을 발급·보관하고 요청에 실어 주는 인증기.
///
/// `NetworkClient` 는 이 프로토콜 뒤만 보므로 토큰의 생김새도 발급 절차도 모른다.
/// actor 인 이유는 두 가지다 — 토큰이 가변 상태이고, **동시 발급 요청을 하나로 합류**시켜야
/// 화면 여러 개가 같은 순간에 401 을 받아도 발급이 1회로 끝나기 때문이다.
actor KISTokenProvider: RequestAuthorizing {
    // MARK: - Property

    private let loadCredentials: @Sendable () async -> KISCredentials?
    private let store: any KISTokenStoring
    private let client: NetworkClient
    private let refreshMargin: TimeInterval
    private let now: @Sendable () -> Date

    private var cachedToken: KISToken?
    private var issueTask: Task<KISToken, any Error>?

    /// 마지막으로 토큰을 발급받을 때 쓴 앱키. 사용자가 키를 바꾼 것을 알아채는 기준이다.
    private var lastCredentials: KISCredentials?

    static let missingCredentialsMessage = "주식·ETF 시세를 보려면 설정에서 KIS 앱키를 넣어 주세요."

    // MARK: - Function

    /// - Parameters:
    ///   - credentials: 요청 시점에 앱키를 읽어 오는 공급자. **저장된 값을 그때그때 읽는 이유는
    ///     앱키가 사용자 입력이라 앱을 켠 뒤에 생기거나 바뀌기 때문이다** — 조립 시점에 값으로
    ///     붙들면 설정에서 키를 넣어도 앱을 다시 켜야 반영된다.
    ///   - refreshMargin: 만료 직전에 미리 갱신할 여유 시간. 401 왕복 자체를 줄인다.
    ///   - now: 현재 시각 공급자. 테스트에서 만료를 앞당기려고 주입한다.
    init(
        credentials loadCredentials: @escaping @Sendable () async -> KISCredentials?,
        store: any KISTokenStoring = KISTokenStore(),
        session: URLSession = .shared,
        refreshMargin: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadCredentials = loadCredentials
        self.store = store
        // 발급 요청 자체는 인증이 없다. 여기에 자기 자신을 authorizer 로 물리면 순환이 생긴다.
        client = NetworkClient(session: session)
        self.refreshMargin = refreshMargin
        self.now = now
    }

    func authorize(_ request: URLRequest) async throws -> URLRequest {
        guard let credentials = await loadCredentials() else {
            throw AppError.unavailable(Self.missingCredentialsMessage)
        }
        let token = try await validToken(for: credentials)

        var authorized = request
        authorized.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "authorization")
        authorized.setValue(credentials.appKey, forHTTPHeaderField: "appkey")
        authorized.setValue(credentials.appSecret, forHTTPHeaderField: "appsecret")
        return authorized
    }

    func invalidate() async {
        cachedToken = nil
        issueTask = nil
        await store.removeAll()
    }

    /// 저장된 앱키로 토큰을 받아 본다. 설정 화면이 키가 맞는지 확인하는 데 쓴다.
    ///
    /// 받아 온 토큰은 버리지 않고 그대로 캐시에 남는다 — KIS 는 발급을 분당 1회로 묶어 두므로,
    /// 확인용으로 한 번 더 받았다가는 정작 첫 시세 조회가 막힌다.
    func verify() async throws {
        guard let credentials = await loadCredentials() else {
            throw AppError.unavailable(Self.missingCredentialsMessage)
        }
        _ = try await validToken(for: credentials)
    }

    /// 메모리 → Keychain → 신규 발급 순으로 유효한 토큰을 구한다.
    ///
    /// 발급 `Task` 를 프로퍼티에 남겨 두는 것이 합류 지점이다. actor 는 재진입 가능해서
    /// `await` 마다 다른 호출이 끼어들 수 있는데, 여기서는 Task 를 저장한 뒤부터 첫 `await`
    /// 까지 중단점이 없으므로 두 번째 호출은 반드시 저장된 Task 를 보게 된다.
    private func validToken(for credentials: KISCredentials) async throws -> KISToken {
        // 키가 바뀌었으면 들고 있던 토큰은 남의 계좌 것이다. 조용히 버리고 다시 받는다.
        if let lastCredentials, lastCredentials != credentials {
            cachedToken = nil
            issueTask = nil
            await store.removeAll()
        }
        lastCredentials = credentials

        if let cachedToken, cachedToken.isValid(at: now(), margin: refreshMargin) {
            return cachedToken
        }

        // 앱을 켜자마자 저장된 토큰을 쓴다. 다른 기기에서 키를 바꿨다면 이 토큰이 어긋나지만,
        // 그건 401 한 번으로 정리된다 — 확인하겠다고 매번 새로 발급하면 KIS 의 분당 1회 제한에
        // 걸려 정작 필요할 때 못 받는다.
        if let stored = await store.load(), stored.isValid(at: now(), margin: refreshMargin) {
            cachedToken = stored
            return stored
        }

        if let issueTask {
            return try await issueTask.value
        }

        let task = Task<KISToken, any Error> { [client, now] in
            let issuedAt = now()
            let dto = try await client.send(
                KISEndpoint.issueToken(
                    appKey: credentials.appKey,
                    appSecret: credentials.appSecret
                ),
                as: KISTokenDTO.self
            )
            return dto.toDomain(issuedAt: issuedAt)
        }
        issueTask = task
        defer { issueTask = nil }

        let token = try await task.value
        cachedToken = token
        await store.save(token)
        return token
    }
}
