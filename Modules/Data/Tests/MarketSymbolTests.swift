//
//  MarketSymbolTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import Testing
@testable import HannunData

@Suite("MarketSymbol")
struct MarketSymbolTests {
    @Test("심볼 표기가 곧 제공자 선택이다", arguments: [
        ("KRW-BTC", MarketSymbol.upbit(market: "KRW-BTC")),
        ("KRW-ETH", .upbit(market: "KRW-ETH")),
        ("005930", .koreaInvestment(.domesticEquity(code: "005930"))),
        ("069500", .koreaInvestment(.domesticEquity(code: "069500"))),
        ("NAS:AAPL", .koreaInvestment(.overseasEquity(exchange: .nasdaq, ticker: "AAPL"))),
        ("NYS:KO", .koreaInvestment(.overseasEquity(exchange: .newYork, ticker: "KO"))),
        ("AMS:SPY", .koreaInvestment(.overseasEquity(exchange: .american, ticker: "SPY"))),
    ])
    func routesBySymbolShape(symbol: String, expected: MarketSymbol) {
        #expect(MarketSymbol(symbol) == expected)
    }

    @Test("거래소를 생략한 해외 티커는 나스닥으로 본다")
    func defaultsUnprefixedTickerToNasdaq() {
        #expect(
            MarketSymbol("AAPL")
                == .koreaInvestment(.overseasEquity(exchange: .nasdaq, ticker: "AAPL"))
        )
    }

    @Test("소문자 티커와 거래소 접두어를 대문자로 맞춘다")
    func normalizesCasing() {
        #expect(
            MarketSymbol("nas:aapl")
                == .koreaInvestment(.overseasEquity(exchange: .nasdaq, ticker: "AAPL"))
        )
    }

    @Test("앞뒤 공백을 걷어낸다")
    func trimsWhitespace() {
        #expect(MarketSymbol("  KRW-BTC ") == .upbit(market: "KRW-BTC"))
        #expect(MarketSymbol(" 005930 ") == .koreaInvestment(.domesticEquity(code: "005930")))
    }

    @Test("6자리가 아닌 숫자는 국내 종목코드로 보지 않는다")
    func requiresSixDigitDomesticCode() {
        #expect(
            MarketSymbol("12345")
                == .koreaInvestment(.overseasEquity(exchange: .nasdaq, ticker: "12345"))
        )
    }

    @Test("모르는 거래소 접두어는 티커의 일부로 남지 않는다")
    func ignoresUnknownExchangePrefix() {
        // 거래소로 해석되지 않으면 문자열 전체가 기본 거래소의 티커가 된다.
        #expect(
            MarketSymbol("XXX:AAPL")
                == .koreaInvestment(.overseasEquity(exchange: .nasdaq, ticker: "XXX:AAPL"))
        )
    }
}
