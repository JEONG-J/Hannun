//
//  KISQuoteTarget.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// KIS 해외 시세 조회가 요구하는 거래소 코드(`EXCD`).
///
/// 설계 문서 §11.0 이 정한 범위가 미국 주식·ETF 이고 `Money` 가 다루는 통화도 KRW·USD
/// 둘뿐이라 미국 3개 거래소만 둔다. 다른 시장을 열려면 `Currency` 확장이 먼저다.
enum KISExchange: String, Sendable, Equatable, CaseIterable {
    case nasdaq = "NAS"
    case newYork = "NYS"
    case american = "AMS"
}

/// KIS 로 보낼 시세 조회 대상.
///
/// 국내와 해외는 경로·`tr_id`·응답 필드·표시 통화가 전부 달라 한 케이스로 합칠 수 없다.
enum KISQuoteTarget: Sendable, Equatable {
    /// 국내 주식·ETF. `code` 는 6자리 종목코드 (예: `005930`)
    case domesticEquity(code: String)

    /// 해외 주식·ETF
    case overseasEquity(exchange: KISExchange, ticker: String)
}
