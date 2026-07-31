//
//  MarketSymbol.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 심볼 문자열 하나를 어느 시세 API 로 보낼지 판별한다.
///
/// 종목을 사용자가 직접 입력하는 앱이라 **심볼 표기가 곧 라우팅 규칙**이다.
///
/// | 입력 | 해석 |
/// |---|---|
/// | `KRW-BTC` | 업비트 마켓 코드 |
/// | `005930` | 6자리 국내 종목코드 (주식·ETF 공통) |
/// | `NAS:AAPL` | 거래소를 명시한 해외 종목 |
/// | `AAPL` | 거래소를 생략한 해외 종목 |
enum MarketSymbol: Sendable, Equatable {
    case upbit(market: String)
    case koreaInvestment(KISQuoteTarget)

    /// 거래소를 생략한 해외 티커에 쓰는 기본 거래소.
    ///
    /// 확인 필요: KIS 해외 현재가 API 는 `EXCD` 를 필수로 받고 거래소를 추론해 주지 않는다.
    /// 실제 상장 거래소와 어긋나면 빈 응답이 와서 해당 심볼만 결과에서 빠지고, 사용자는
    /// 현재가 수동 입력 폴백(설계 문서 PF-2)으로 넘어간다. `NYS:KO` 처럼 접두어를 붙이면
    /// 추측을 건너뛴다.
    private static let defaultOverseasExchange = KISExchange.nasdaq

    /// 업비트 마켓 코드 접두어. KRW 마켓만 다루므로 이것만 보면 구분이 끝난다.
    private static let upbitMarketPrefix = "KRW-"

    /// 국내 종목코드 자릿수.
    private static let domesticCodeLength = 6

    init(_ symbol: String) {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.uppercased().hasPrefix(Self.upbitMarketPrefix) {
            self = .upbit(market: trimmed)
            return
        }

        if trimmed.count == Self.domesticCodeLength,
           trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) {
            self = .koreaInvestment(.domesticEquity(code: trimmed))
            return
        }

        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2,
           let exchange = KISExchange(rawValue: String(parts[0]).uppercased()) {
            self = .koreaInvestment(
                .overseasEquity(exchange: exchange, ticker: String(parts[1]).uppercased())
            )
            return
        }

        self = .koreaInvestment(
            .overseasEquity(exchange: Self.defaultOverseasExchange, ticker: trimmed.uppercased())
        )
    }
}
