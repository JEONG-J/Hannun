//
//  MarketCredentialsRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/8/26.
//

import HannunCore
import HannunDomain

/// `MarketCredentialsServiceProtocol` 의 실제 구현.
///
/// 조립은 `MarketRepositories` 가 맡는다 — **여기서 토큰 발급기를 새로 만들면 시세 쪽과
/// 갈라진다.** 발급기가 둘이면 설정 화면이 확인용으로 받은 토큰을 시세 쪽이 못 보고 다시
/// 받으려 하는데, KIS 는 발급을 분당 1회로 묶어 두므로 그 요청이 막힌다.
struct MarketCredentialsRepository: MarketCredentialsServiceProtocol {
    // MARK: - Property

    private let store: KISCredentialsStore
    private let tokenProvider: KISTokenProvider

    // MARK: - Function

    init(store: KISCredentialsStore, tokenProvider: KISTokenProvider) {
        self.store = store
        self.tokenProvider = tokenProvider
    }

    func isConfigured() async -> Bool {
        await store.load() != nil
    }

    /// 저장 → 확인 → (실패 시) 되돌리기 순서다.
    ///
    /// 확인을 먼저 하고 저장할 수는 없다. 토큰 발급기는 저장된 키를 읽어 쓰므로, 저장 전에는
    /// 확인할 대상 자체가 없다. 그래서 새 키를 먼저 앉히고 실패했을 때 이전 값을 되돌린다 —
    /// 틀린 키를 남겨 두면 설정 화면은 "연결됨" 인데 시세만 계속 실패하는 상태가 된다.
    func save(appKey: String, appSecret: String) async throws {
        guard let candidate = KISCredentials.sanitized(appKey: appKey, appSecret: appSecret) else {
            throw AppError.validation("앱키와 앱시크릿을 모두 입력해 주세요.")
        }

        let previous = await store.load()
        // 같은 키를 다시 저장하는 건 확인 요청을 한 번 더 태울 이유가 없다.
        guard previous != candidate else { return }

        await store.save(candidate)

        do {
            try await tokenProvider.verify()
        } catch {
            if let previous {
                await store.save(previous)
            } else {
                await store.removeAll()
            }
            throw AppError(narrowing: error)
        }
    }

    func remove() async {
        await store.removeAll()
        await tokenProvider.invalidate()
    }
}
