//
//  ExchangeRateStore.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 마지막으로 조회에 성공한 환율 한 건.
struct StoredExchangeRate: Codable, Sendable, Equatable {
    let krwPerUSD: Decimal
    let updatedAt: Date
}

/// 환율 보관소. 프로덕션 구현은 `UserDefaults` 이고, 테스트는 인메모리 스텁을 끼운다.
protocol ExchangeRateStoring: Sendable {
    func load() async -> StoredExchangeRate?
    func save(_ rate: StoredExchangeRate) async
}

/// `UserDefaults` 기반 환율 저장소.
///
/// 앱을 껐다 켠 직후에도 마지막 환율이 남아 있어야 한다 (NW-2). 인메모리 캐시만 두면 콜드
/// 스타트 + 네트워크 장애가 겹칠 때 해외 자산이 통째로 0원으로 보인다.
///
/// 접근토큰과 달리 환율은 비밀이 아니라 새어 나가도 잃을 것이 없다. Keychain 은 과하다.
struct UserDefaultsExchangeRateStore: ExchangeRateStoring {
    // MARK: - Property

    private let suiteName: String?
    private let key: String

    /// `UserDefaults` 는 `Sendable` 이 아니라 프로퍼티로 붙들면 이 타입이 동시성 경계를 넘지
    /// 못한다. 이름만 들고 있다가 쓸 때 꺼내면 `@unchecked` 없이도 안전하다.
    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    // MARK: - Function

    /// - Parameter suiteName: nil 이면 앱 기본 저장소. 테스트는 격리된 이름을 준다.
    init(suiteName: String? = nil, key: String = "last-known-exchange-rate") {
        self.suiteName = suiteName
        self.key = key
    }

    func load() async -> StoredExchangeRate? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredExchangeRate.self, from: data)
    }

    func save(_ rate: StoredExchangeRate) async {
        guard let data = try? JSONEncoder().encode(rate) else { return }
        defaults.set(data, forKey: key)
    }
}
