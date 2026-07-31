//
//  KISTokenStoreTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import Security
import Testing
@testable import HannunData

/// 앱 호스트 없는 유닛 테스트 번들에는 keychain-access-groups 엔타이틀먼트가 없어
/// `SecItemAdd` 가 errSecMissingEntitlement(-34018) 로 막힌다. 쓰기가 되는 환경에서만 돌린다.
private let isKeychainWritable: Bool = {
    let probe: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.jeong.hannun.kis.tests",
        kSecAttrAccount as String: "entitlement-probe",
    ]
    var insertion = probe
    insertion[kSecValueData as String] = Data()

    let status = SecItemAdd(insertion as CFDictionary, nil)
    guard status == errSecSuccess || status == errSecDuplicateItem else { return false }

    _ = SecItemDelete(probe as CFDictionary)
    return true
}()

/// Keychain 은 프로세스 전역이라 병렬로 돌리면 테스트끼리 서로의 항목을 덮어쓴다.
@Suite(
    "KISTokenStore",
    .serialized,
    .enabled(if: isKeychainWritable, "Keychain 쓰기 권한이 없는 테스트 번들에서는 건너뛴다")
)
struct KISTokenStoreTests {
    private static let service = "com.jeong.hannun.kis.tests"
    private static let expiresAt = Date(timeIntervalSince1970: 1_785_086_400)

    private func makeStore(account: String) -> KISTokenStore {
        KISTokenStore(service: Self.service, account: account)
    }

    @Test("저장한 토큰을 그대로 되돌려준다")
    func storesAndLoadsToken() async throws {
        let store = makeStore(account: "round-trip")
        await store.removeAll()

        let token = KISToken(accessToken: "kis-access-token", expiresAt: Self.expiresAt)
        await store.save(token)

        #expect(await store.load() == token)

        await store.removeAll()
    }

    @Test("같은 계정에 다시 저장하면 최신 토큰만 남는다")
    func overwritesPreviousToken() async throws {
        let store = makeStore(account: "overwrite")
        await store.removeAll()

        await store.save(KISToken(accessToken: "old", expiresAt: Self.expiresAt))
        await store.save(KISToken(accessToken: "new", expiresAt: Self.expiresAt))

        #expect(await store.load()?.accessToken == "new")

        await store.removeAll()
    }

    @Test("비우고 나면 아무것도 남지 않는다")
    func removesStoredToken() async throws {
        let store = makeStore(account: "remove")

        await store.save(KISToken(accessToken: "to-remove", expiresAt: Self.expiresAt))
        await store.removeAll()

        #expect(await store.load() == nil)
    }

    @Test("저장한 적 없는 계정은 nil 이다")
    func returnsNilForUnknownAccount() async throws {
        let store = makeStore(account: "never-written-\(UUID().uuidString)")

        #expect(await store.load() == nil)
    }
}
