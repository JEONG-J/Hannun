//
//  KISCredentialsStore.swift
//  HannunData
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation
import Security

/// Keychain 기반 앱키 저장소.
///
/// 접근토큰(`KISTokenStore`)과 달리 **iCloud Keychain 으로 동기화한다.** 자산 데이터는 이미
/// CloudKit 으로 기기 사이를 오가는데(설계 문서 §10) 앱키만 기기마다 다시 입력하게 두면,
/// 아이패드에서 앱을 열었을 때 같은 종목이 시세 없이 뜬다. 토큰은 기기마다 새로 받으면 그만이라
/// 동기화할 이유가 없지만, 앱키는 사용자가 한 번 넣은 값 그대로 따라다녀야 한다.
///
/// 동기화 항목은 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 를 쓸 수 없다 —
/// 기기 밖으로 나가지 않는다는 뜻이라 동기화와 배타적이다. 그래서 한 단계 넓은
/// `AfterFirstUnlock` 을 건다. iCloud Keychain 구간은 Apple 이 종단간 암호화한다.
actor KISCredentialsStore {
    // MARK: - Property

    private let service: String
    private let account: String

    // MARK: - Function

    init(service: String = "com.jeong.hannun.kis", account: String = "credentials") {
        self.service = service
        self.account = account
    }

    func load() async -> KISCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }

        return try? JSONDecoder().decode(KISCredentials.self, from: data)
    }

    /// 삭제 후 추가한다. 갱신/추가를 분기하는 것보다 상태가 하나뿐이라 어긋날 여지가 없다.
    func save(_ credentials: KISCredentials) async {
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        _ = SecItemDelete(baseQuery as CFDictionary)
        _ = SecItemAdd(attributes as CFDictionary, nil)
    }

    func removeAll() async {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    /// `kSecAttrSynchronizable` 은 저장할 때만이 아니라 **조회·삭제 질의에도** 있어야 한다.
    /// 빠뜨리면 동기화 항목이 검색 대상에서 빠져 방금 저장한 값을 못 찾는다.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
    }
}
