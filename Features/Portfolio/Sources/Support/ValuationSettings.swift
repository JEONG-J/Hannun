//
//  ValuationSettings.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore

/// 평가금액을 환산할 기준 통화와 환율.
///
/// 환율을 내려주는 UseCase 가 아직 없어 상수를 쓴다. 조회 계층이 붙기 전까지 해외 자산의
/// 원화 평가금액은 이 값에 묶인다.
enum ValuationSettings {
    static let baseCurrency: Currency = .krw
    static let exchangeRate = ExchangeRate(krwPerUSD: 1_380)
}
