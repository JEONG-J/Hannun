//
//  UpbitEndpoint.swift
//  HannunData
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation

/// 업비트 공개 시세(Quotation) API.
/// 인증이 필요 없어 토큰·앱키 관련 설정이 전혀 없다.
enum UpbitEndpoint: Endpoint {
    /// 여러 마켓의 현재가를 한 번에 조회한다. 마켓 코드 예: `KRW-BTC`
    case ticker(markets: [String])

    private static let host = URL(string: "https://api.upbit.com")!

    var baseURL: URL { Self.host }

    var path: String {
        switch self {
        case .ticker: "/v1/ticker"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .ticker(markets):
            [URLQueryItem(name: "markets", value: markets.joined(separator: ","))]
        }
    }
}
