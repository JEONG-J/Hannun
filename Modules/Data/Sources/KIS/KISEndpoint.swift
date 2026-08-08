//
//  KISEndpoint.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 접근토큰 발급 요청 본문. 앱키·앱시크릿을 헤더가 아니라 본문으로 보낸다.
private struct KISTokenRequestBody: Encodable {
    let grantType = "client_credentials"
    let appKey: String
    let appSecret: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case appKey = "appkey"
        case appSecret = "appsecret"
    }
}

/// 한국투자증권 Open API 엔드포인트.
///
/// 앱키·앱시크릿을 토큰 발급 케이스의 연관값으로 받는다. 선언부가 시크릿 저장소를 직접 읽으면
/// 테스트에서 더미 키로 갈아 끼울 수 없고, 저장소 위치가 바뀔 때마다 이 파일이 따라 바뀐다.
enum KISEndpoint: Endpoint {
    /// 접근토큰 발급. KIS 는 refresh token 을 주지 않아 만료되면 이 요청을 다시 보낸다.
    case issueToken(appKey: String, appSecret: String)

    /// 국내 주식·ETF 현재가
    case domesticQuote(code: String)

    /// 해외 주식·ETF 현재가
    case overseasQuote(exchange: KISExchange, ticker: String)

    /// 원/달러 환율. 기간을 받는 이유는 이 API 가 기간별 시세이기 때문이다 —
    /// 주말·공휴일에는 당일 고시가 없어 며칠을 함께 요청해야 값이 비지 않는다.
    case exchangeRate(from: Date, to: Date)

    /// 실전투자 도메인. 모의투자는 `https://openapivts.koreainvestment.com:29443` 이고
    /// `tr_id` 앞 글자도 함께 바뀌므로, 지원하게 되면 host 와 `tr_id` 를 같이 분기해야 한다.
    private static let host = URL(string: "https://openapi.koreainvestment.com:9443")!

    var baseURL: URL { Self.host }

    var path: String {
        switch self {
        case .issueToken: "/oauth2/tokenP"
        case .domesticQuote: "/uapi/domestic-stock/v1/quotations/inquire-price"
        case .overseasQuote: "/uapi/overseas-price/v1/quotations/price"
        // 환율 전용 엔드포인트가 따로 없어 해외지수 기간별 시세 API 를 쓴다.
        // 계좌번호를 요구하는 잔고 계열 환율(`CTRP6504R`)은 앱이 앱키만 갖고 있어 쓸 수 없다.
        case .exchangeRate: "/uapi/overseas-price/v1/quotations/inquire-daily-chartprice"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .issueToken: .post
        case .domesticQuote, .overseasQuote, .exchangeRate: .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .issueToken:
            []

        case let .domesticQuote(code):
            // `J` 는 주식·ETF·ETN 을 함께 덮는 시장 분류 코드다.
            [
                URLQueryItem(name: "FID_COND_MRKT_DIV_CODE", value: "J"),
                URLQueryItem(name: "FID_INPUT_ISCD", value: code),
            ]

        case let .overseasQuote(exchange, ticker):
            // `AUTH` 는 빈 값으로 보내는 자리표시자다. 빼면 KIS 가 필수 파라미터 누락으로 막는다.
            [
                URLQueryItem(name: "AUTH", value: ""),
                URLQueryItem(name: "EXCD", value: exchange.rawValue),
                URLQueryItem(name: "SYMB", value: ticker),
            ]

        case let .exchangeRate(from, to):
            // `X` 는 환율 시장 분류 코드, `FX@KRW` 는 원/달러 종목 코드, `D` 는 일봉이다.
            // 실키로 확인했다 — `output1.hts_kor_isnm` 이 "원/달러(KMB)" 로 온다.
            [
                URLQueryItem(name: "FID_COND_MRKT_DIV_CODE", value: "X"),
                URLQueryItem(name: "FID_INPUT_ISCD", value: "FX@KRW"),
                URLQueryItem(name: "FID_INPUT_DATE_1", value: Self.requestDate(from)),
                URLQueryItem(name: "FID_INPUT_DATE_2", value: Self.requestDate(to)),
                URLQueryItem(name: "FID_PERIOD_DIV_CODE", value: "D"),
            ]
        }
    }

    var headers: [String: String] {
        var headers = ["content-type": "application/json; charset=utf-8"]

        if let transactionID {
            headers["tr_id"] = transactionID
            // 개인 고객. 법인은 `B` 이고 `personalseckey` 헤더가 추가로 필요하다.
            headers["custtype"] = "P"
        }
        return headers
    }

    var body: Data? {
        switch self {
        case let .issueToken(appKey, appSecret):
            // String 세 개만 담는 구조라 인코딩이 실패할 수 없다.
            try? JSONEncoder().encode(
                KISTokenRequestBody(appKey: appKey, appSecret: appSecret)
            )

        case .domesticQuote, .overseasQuote, .exchangeRate:
            nil
        }
    }

    var authentication: EndpointAuthentication {
        switch self {
        case .issueToken: .none
        case .domesticQuote, .overseasQuote, .exchangeRate: .kisAccessToken
        }
    }

    /// KIS 는 날짜를 한국 시간 기준 `yyyyMMdd` 로 받는다.
    ///
    /// `DateFormatter` 는 `Sendable` 이 아니라 전역 상수로 둘 수 없고, 요청마다 새로 만들면
    /// 로캘·역법 설정이 기기 설정을 따라가 흔들린다. 그래서 컴포넌트를 직접 조립한다.
    private static func requestDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoulTimeZone

        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    private static let seoulTimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    /// KIS 는 경로가 같아도 `tr_id` 로 거래 종류를 가른다. 그래서 헤더 분기가 곧 엔드포인트 분기다.
    ///
    /// 아래 세 값은 실전투자 실키로 호출해 `rt_cd=0` 을 확인했다. KIS 문서가 수시로
    /// 갱신되므로(설계 문서 §11.2) 응답이 이상하면 `msg1` 부터 본다.
    private var transactionID: String? {
        switch self {
        case .issueToken: nil
        case .domesticQuote: "FHKST01010100"
        case .overseasQuote: "HHDFS00000300"
        case .exchangeRate: "FHKST03030100"
        }
    }
}
