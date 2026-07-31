//
//  ExchangeRateCache.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 환율 캐시. 유효 기간 안이면 저장된 값을 그대로 쓰고, 만료돼도 마지막 값은 버리지 않는다.
///
/// 저장소 읽기 결과를 메모하는 가변 상태가 있어 actor 다.
actor ExchangeRateCache {
    // MARK: - Property

    private let storage: any ExchangeRateStoring
    private let timeToLive: TimeInterval
    private let now: @Sendable () -> Date

    private var memoized: StoredExchangeRate?

    // MARK: - Function

    /// - Parameter timeToLive: 유효 기간. 기본 1시간이다 — 환율은 시세와 달리 일 단위로 고시되고
    ///   같은 KIS 호출량 제한을 시세 조회와 나눠 쓰므로, 시세의 15분보다 넉넉하게 잡는다.
    init(
        storage: any ExchangeRateStoring = UserDefaultsExchangeRateStore(),
        timeToLive: TimeInterval = 60 * 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.storage = storage
        self.timeToLive = timeToLive
        self.now = now
    }

    /// 유효 기간 안의 환율만 돌려준다.
    func validRate() async -> ExchangeRate? {
        guard let stored = await loaded() else { return nil }
        guard now().timeIntervalSince(stored.updatedAt) < timeToLive else { return nil }
        return ExchangeRate(krwPerUSD: stored.krwPerUSD)
    }

    /// 만료 여부를 따지지 않고 마지막으로 성공한 환율을 돌려준다.
    /// "환율 조회 실패 시 마지막 캐시 환율 사용"(NW-2) 정책이 기대는 값이다.
    func lastKnownRate() async -> ExchangeRate? {
        await loaded().map { ExchangeRate(krwPerUSD: $0.krwPerUSD) }
    }

    func store(_ rate: ExchangeRate) async {
        let record = StoredExchangeRate(krwPerUSD: rate.krwPerUSD, updatedAt: now())

        memoized = record
        await storage.save(record)
    }

    /// 저장소는 앱 실행 중 이 캐시 말고는 아무도 건드리지 않으므로 한 번만 읽는다.
    private func loaded() async -> StoredExchangeRate? {
        if let memoized { return memoized }

        memoized = await storage.load()
        return memoized
    }
}
