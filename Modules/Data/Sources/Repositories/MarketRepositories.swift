//
//  MarketRepositories.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain

/// 시세·환율 저장소를 **한 벌의 KIS 클라이언트 위에** 조립한다.
///
/// 두 저장소가 각자 `KISClient` 를 만들면 `KISTokenProvider` 도 둘이 되어, 앱을 처음 켤 때
/// 두 저장소가 동시에 조회하면 접근토큰을 두 번 발급받는다. KIS 는 발급 호출 자체에 빈도 제한을
/// 두므로 둘 중 하나가 막힌다. 그래서 클라이언트를 만드는 지점을 여기 하나로 모으고,
/// 저장소는 이미 만들어진 클라이언트를 받기만 한다.
public struct MarketRepositories: Sendable {
    // MARK: - Property

    public let marketData: any MarketDataServiceProtocol
    public let exchangeRate: any ExchangeRateServiceProtocol

    // MARK: - Function

    public init(session: URLSession = .shared) {
        self.init(
            session: session,
            koreaInvestment: KISClient.makeIfConfigured(session: session),
            quoteCache: QuoteCache(),
            exchangeRateCache: ExchangeRateCache()
        )
    }

    init(
        session: URLSession,
        koreaInvestment: KISClient?,
        quoteCache: QuoteCache,
        exchangeRateCache: ExchangeRateCache
    ) {
        marketData = MarketDataRepository(
            upbit: UpbitClient(session: session),
            koreaInvestment: koreaInvestment,
            cache: quoteCache
        )
        exchangeRate = ExchangeRateRepository(
            koreaInvestment: koreaInvestment,
            cache: exchangeRateCache
        )
    }
}
