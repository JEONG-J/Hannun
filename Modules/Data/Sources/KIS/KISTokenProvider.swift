//
//  KISTokenProvider.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// KIS 접근토큰을 발급·보관하고 요청에 실어 주는 인증기.
///
/// `NetworkClient` 는 이 프로토콜 뒤만 보므로 토큰의 생김새도 발급 절차도 모른다.
/// actor 인 이유는 두 가지다 — 토큰이 가변 상태이고, **동시 발급 요청을 하나로 합류**시켜야
/// 화면 여러 개가 같은 순간에 401 을 받아도 발급이 1회로 끝나기 때문이다.
actor KISTokenProvider: RequestAuthorizing {
    // MARK: - Property

    private let credentials: KISCredentials
    private let store: any KISTokenStoring
    private let client: NetworkClient
    private let refreshMargin: TimeInterval
    private let now: @Sendable () -> Date

    private var cachedToken: KISToken?
    private var issueTask: Task<KISToken, any Error>?

    // MARK: - Function

    /// - Parameters:
    ///   - refreshMargin: 만료 직전에 미리 갱신할 여유 시간. 401 왕복 자체를 줄인다.
    ///   - now: 현재 시각 공급자. 테스트에서 만료를 앞당기려고 주입한다.
    init(
        credentials: KISCredentials,
        store: any KISTokenStoring = KISTokenStore(),
        session: URLSession = .shared,
        refreshMargin: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.credentials = credentials
        self.store = store
        // 발급 요청 자체는 인증이 없다. 여기에 자기 자신을 authorizer 로 물리면 순환이 생긴다.
        client = NetworkClient(session: session)
        self.refreshMargin = refreshMargin
        self.now = now
    }

    func authorize(_ request: URLRequest) async throws -> URLRequest {
        let token = try await validToken()

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

    /// 메모리 → Keychain → 신규 발급 순으로 유효한 토큰을 구한다.
    ///
    /// 발급 `Task` 를 프로퍼티에 남겨 두는 것이 합류 지점이다. actor 는 재진입 가능해서
    /// `await` 마다 다른 호출이 끼어들 수 있는데, 여기서는 Task 를 저장한 뒤부터 첫 `await`
    /// 까지 중단점이 없으므로 두 번째 호출은 반드시 저장된 Task 를 보게 된다.
    private func validToken() async throws -> KISToken {
        if let cachedToken, cachedToken.isValid(at: now(), margin: refreshMargin) {
            return cachedToken
        }

        if let stored = await store.load(), stored.isValid(at: now(), margin: refreshMargin) {
            cachedToken = stored
            return stored
        }

        if let issueTask {
            return try await issueTask.value
        }

        let task = Task<KISToken, any Error> { [credentials, client, now] in
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
