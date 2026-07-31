import Foundation
import HannunCore
import Testing
@testable import HannunData

private struct SampleEndpoint: Endpoint {
    var baseURL = URL(string: "https://api.example.com")!
    var path = "/v1/ticker"
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?
    var authentication: EndpointAuthentication = .none
}

@Suite("Endpoint")
struct EndpointTests {
    @Test("path 와 baseURL 을 이어 요청 URL 을 만든다")
    func buildsURL() throws {
        let request = try SampleEndpoint().makeRequest()

        #expect(request.url?.absoluteString == "https://api.example.com/v1/ticker")
        #expect(request.httpMethod == "GET")
    }

    @Test("쿼리 파라미터를 퍼센트 인코딩한다")
    func encodesQueryItems() throws {
        var endpoint = SampleEndpoint()
        endpoint.queryItems = [URLQueryItem(name: "markets", value: "KRW-BTC,KRW-ETH")]

        let request = try endpoint.makeRequest()
        let url = try #require(request.url)

        // 콤마는 인코딩되거나 그대로 남을 수 있으므로 디코딩된 값으로 비교한다.
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first?.value == "KRW-BTC,KRW-ETH")
    }

    @Test("헤더와 본문을 요청에 싣는다")
    func appliesHeadersAndBody() throws {
        var endpoint = SampleEndpoint()
        endpoint.method = .post
        endpoint.headers = ["content-type": "application/json"]
        endpoint.body = Data(#"{"grant_type":"client_credentials"}"#.utf8)

        let request = try endpoint.makeRequest()

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
        #expect(request.httpBody == endpoint.body)
    }

    @Test("기본 인증 방식은 none 이다")
    func defaultsToNoAuthentication() {
        #expect(UpbitEndpoint.ticker(markets: ["KRW-BTC"]).authentication == .none)
    }
}
