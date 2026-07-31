//
//  Endpoint.swift
//  HannunData
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore

/// 엔드포인트가 요구하는 인증 방식.
///
/// 외부 API 가 둘(KIS, 업비트)이고 인증 체계가 서로 다르기 때문에,
/// "이 요청에 인증이 필요한가"를 정책 객체가 아니라 엔드포인트 자신이 선언한다.
enum EndpointAuthentication: Equatable, Sendable {
    /// 인증 없음. 업비트 Quotation API 가 여기에 해당한다.
    case none

    /// KIS 접근토큰(Bearer) + 앱키·앱시크릿 헤더를 붙인다.
    case kisAccessToken
}

/// 하나의 API 호출을 선언적으로 기술한다.
///
/// `path` 외에는 전부 기본 구현이 있으므로, 단순 조회 엔드포인트는 `baseURL` 과 `path` 만
/// 채우면 된다. `URLRequest` 조립은 `makeRequest()` 가 전담한다.
protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    var authentication: EndpointAuthentication { get }
}

extension Endpoint {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var body: Data? { nil }
    var authentication: EndpointAuthentication { .none }

    /// 선언을 실제 요청으로 조립한다.
    /// 퍼센트 인코딩은 `URLComponents` 가 처리하므로 직접 문자열을 이어붙이지 않는다.
    func makeRequest() throws -> URLRequest {
        let url = baseURL.appending(path: path)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppError.network("URL 을 만들 수 없습니다: \(url.absoluteString)")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let requestURL = components.url else {
            throw AppError.network("쿼리 인코딩에 실패했습니다: \(path)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
