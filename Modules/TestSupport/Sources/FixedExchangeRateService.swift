//
//  FixedExchangeRateService.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// 환율을 고정값으로 돌려주는 `ExchangeRateServiceProtocol` 대역.
///
/// 실제 구현은 캐시·네트워크를 거치므로 환산 결과가 흔들린다. 금액을 단언하는 테스트는
/// 환율을 붙박아 두고 계산만 검증한다.
public struct FixedExchangeRateService: ExchangeRateServiceProtocol {
    // MARK: - Property

    private let rate: ExchangeRate

    // MARK: - Function

    public init(krwPerUSD: Decimal = 1_380) {
        rate = ExchangeRate(krwPerUSD: krwPerUSD)
    }

    public func currentRate() async -> ExchangeRate { rate }
}
