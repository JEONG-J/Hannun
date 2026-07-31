//
//  QuoteCache.swift
//  HannunData
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore

/// 시세 캐시. KIS·업비트 모두 호출량 제한이 있어 15분 캐싱을 요구한다.
///
/// 딕셔너리를 공유 가변 상태로 들고 있으므로 actor 여야 한다 —
/// Swift 6 complete 모드에서는 `class` + 가변 딕셔너리 조합이 아예 컴파일되지 않는다.
actor QuoteCache {
    private struct Entry {
        let money: Money
        let storedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let timeToLive: TimeInterval
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - timeToLive: 유효 기간. 기본 15분
    ///   - now: 현재 시각 공급자. 테스트에서 시간을 앞당기려고 주입한다.
    init(
        timeToLive: TimeInterval = 15 * 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.timeToLive = timeToLive
        self.now = now
    }

    /// 유효 기간 안의 값만 돌려준다.
    ///
    /// 만료된 항목을 **지우지 않는다** — 폴백은 갱신 실패 시점에 만료된 값을 다시 꺼내 쓰기
    /// 때문이다. 여기서 버리면 `staleValue(for:)` 가 항상 nil 이 되어 폴백 자체가 죽는다.
    /// 키는 사용자 보유 종목 수만큼만 늘어나므로 방치해도 문제되지 않는다.
    func value(for key: String) -> Money? {
        guard let entry = entries[key] else { return nil }
        guard now().timeIntervalSince(entry.storedAt) < timeToLive else { return nil }
        return entry.money
    }

    /// 만료 여부를 따지지 않고 마지막으로 받아둔 값을 돌려준다.
    /// "갱신 실패 시 마지막 캐시값 사용 + 갱신 실패 배지" 정책에 쓰인다.
    func staleValue(for key: String) -> Money? {
        entries[key]?.money
    }

    func store(_ money: Money, for key: String) {
        entries[key] = Entry(money: money, storedAt: now())
    }

    func store(_ prices: [String: Money]) {
        let storedAt = now()
        for (key, money) in prices {
            entries[key] = Entry(money: money, storedAt: storedAt)
        }
    }

    func removeAll() {
        entries.removeAll()
    }
}
