//
//  MarketRepositories.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain

/// 시세·환율·자격증명 저장소를 **한 벌의 토큰 발급기 위에** 조립한다.
///
/// 셋이 각자 발급기를 만들면 앱을 켜는 순간 접근토큰을 여러 번 발급받는다. KIS 는 발급 호출
/// 자체에 분당 1회 제한을 두므로 그중 하나만 살아남는다. 그래서 발급기를 만드는 지점을 여기
/// 하나로 모으고, 저장소는 이미 만들어진 것을 받기만 한다.
///
/// 앱키가 있는지로 조립이 갈라지지 않는 것도 같은 이유의 연장이다 — 앱키는 사용자가 설정에서
/// 넣는 값이라 앱을 켠 뒤에 생기거나 바뀐다. 키가 없는 동안은 발급기가 요청 시점에
/// `unavailable` 을 던지고, 코인 시세와 수동 입력 폴백은 그대로 살아 있다.
public struct MarketRepositories: Sendable {
    // MARK: - Property

    public let marketData: any MarketDataServiceProtocol
    public let exchangeRate: any ExchangeRateServiceProtocol
    public let credentials: any MarketCredentialsServiceProtocol

    // MARK: - Function

    public init(session: URLSession = .shared) {
        let credentialsStore = KISCredentialsStore()
        let tokenProvider = KISTokenProvider(
            credentials: { await credentialsStore.load() },
            session: session
        )

        self.init(
            session: session,
            koreaInvestment: KISClient(session: session, authorizer: tokenProvider),
            credentials: MarketCredentialsRepository(
                store: credentialsStore,
                tokenProvider: tokenProvider
            ),
            quoteCache: QuoteCache(),
            exchangeRateCache: ExchangeRateCache()
        )
    }

    init(
        session: URLSession,
        koreaInvestment: KISClient?,
        credentials: any MarketCredentialsServiceProtocol,
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
        self.credentials = credentials
    }
}
