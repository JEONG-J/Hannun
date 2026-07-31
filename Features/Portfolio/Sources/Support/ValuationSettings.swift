//
//  ValuationSettings.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore

/// 평가금액을 환산할 기준 통화.
///
/// 포트폴리오 탭에는 아직 통화 토글이 없어 원화로 고정한다. 환율은 상수가 아니라
/// `ExchangeRateServiceProtocol` 로 주입받는다 — 탭마다 다른 환율을 쓰면 같은 자산이
/// 화면마다 다른 금액으로 보인다.
enum ValuationSettings {
    static let baseCurrency: Currency = .krw
}
