//
//  KISTokenStore.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import Security

/// 접근토큰 보관소. 프로덕션 구현은 Keychain 이고, 테스트는 인메모리 스텁을 끼운다.
protocol KISTokenStoring: Sendable {
    func load() async -> KISToken?
    func save(_ token: KISToken) async
    func removeAll() async
}

/// Keychain 기반 토큰 저장소.
///
/// 접근토큰은 24시간 동안 계좌 API 를 열어 주는 자격증명이다. `UserDefaults` 는 평문 plist 라
/// 기기 백업이나 파일 접근만으로 그대로 새어 나가므로 쓰지 않는다.
///
/// 항목은 **기기에 묶고 iCloud 로 동기화하지 않는다** — 다른 기기에서는 그 기기의 앱키로
/// 새로 발급받는 편이 맞고, 자격증명을 클라우드에 흘릴 이유도 없다.
actor KISTokenStore: KISTokenStoring {
    // MARK: - Property

    private let service: String
    private let account: String

    // MARK: - Function

    init(service: String = "com.jeong.hannun.kis", account: String = "access-token") {
        self.service = service
        self.account = account
    }

    func load() async -> KISToken? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }

        return try? JSONDecoder().decode(KISToken.self, from: data)
    }

    /// 삭제 후 추가한다. 갱신/추가를 분기하는 것보다 상태가 하나뿐이라 어긋날 여지가 없다.
    func save(_ token: KISToken) async {
        guard let data = try? JSONEncoder().encode(token) else { return }

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        _ = SecItemDelete(baseQuery as CFDictionary)
        _ = SecItemAdd(attributes as CFDictionary, nil)
    }

    func removeAll() async {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
