//
//  ExchangeRateServiceProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore

/// 환율 조회 창구. 실제 구현(`ExchangeRateRepository`)은 HannunData 에 있다 (봉인 규칙).
///
/// 순자산·포트폴리오·성과 세 탭이 같은 환율로 환산해야 하므로 값의 출처를 여기 하나로 모은다.
public protocol ExchangeRateServiceProtocol: Sendable {
    /// 지금 쓸 USD/KRW 환율.
    ///
    /// **던지지 않는다.** 조회에 실패하면 마지막으로 성공한 환율로 버티고(NW-2), 그마저 없으면
    /// 구현이 정한 씨앗 값을 준다. 환율을 못 구했다는 이유로 화면을 비우면 시세는 멀쩡한
    /// 원화 자산까지 함께 사라지기 때문이다.
    func currentRate() async -> ExchangeRate
}
