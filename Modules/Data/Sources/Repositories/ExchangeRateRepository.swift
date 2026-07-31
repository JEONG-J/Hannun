//
//  ExchangeRateRepository.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// `ExchangeRateServiceProtocol` 의 실제 구현.
///
/// KIS 에서 원/달러 고시 환율을 받아오고, 앞단에 유효 기간 캐시를 둔다.
/// 갱신에 실패하면 마지막으로 성공한 환율로 버틴다 (NW-2).
public struct ExchangeRateRepository: ExchangeRateServiceProtocol {
    // MARK: - Property

    /// KIS 앱키가 없으면 nil 이다. 키가 없어도 원화 자산은 그대로 보여야 한다.
    private let koreaInvestment: KISClient?

    private let cache: ExchangeRateCache

    /// 한 번도 조회에 성공한 적이 없을 때만 쓰는 씨앗 환율.
    ///
    /// 확인 필요: 실제 고시 환율이 아니라 첫 조회가 성공할 때까지 버티는 값이다. 세 탭이 각자
    /// 다른 상수를 들고 있던 문제를 되풀이하지 않도록 앱 전체에서 이 한 곳에만 둔다.
    static let seedRate = ExchangeRate(krwPerUSD: 1_380)

    // MARK: - Function

    /// 조립은 `MarketRepositories` 가 맡는다 — KIS 클라이언트를 여기서 만들면
    /// 시세 저장소와 토큰 발급이 갈라진다.
    init(koreaInvestment: KISClient?, cache: ExchangeRateCache) {
        self.koreaInvestment = koreaInvestment
        self.cache = cache
    }

    /// 캐시 → 조회 → 마지막 성공값 → 씨앗 값 순으로 내려간다.
    ///
    /// 조회 실패를 던지지 않고 삼키는 유일한 지점이다. 환율 하나 때문에 화면 전체가 비면
    /// 시세가 멀쩡한 원화 자산까지 사라지기 때문이다 (프로토콜 주석 참고).
    public func currentRate() async -> ExchangeRate {
        if let fresh = await cache.validRate() { return fresh }

        if let koreaInvestment, let fetched = try? await koreaInvestment.exchangeRate() {
            await cache.store(fetched)
            return fetched
        }
        return await cache.lastKnownRate() ?? Self.seedRate
    }
}
