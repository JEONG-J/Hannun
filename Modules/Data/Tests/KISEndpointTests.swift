//
//  KISEndpointTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import Testing
@testable import HannunData

@Suite("KISEndpoint")
struct KISEndpointTests {
    @Test("토큰 발급은 인증 없이 앱키·시크릿을 본문으로 보낸다")
    func issueTokenSendsCredentialsInBody() throws {
        let endpoint = KISEndpoint.issueToken(appKey: "key", appSecret: "secret")
        let request = try endpoint.makeRequest()

        #expect(endpoint.authentication == .none)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/oauth2/tokenP")
        #expect(request.value(forHTTPHeaderField: "tr_id") == nil)

        let body = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        #expect(json["grant_type"] == "client_credentials")
        #expect(json["appkey"] == "key")
        #expect(json["appsecret"] == "secret")
    }

    @Test("국내 현재가는 시장 분류·종목코드 쿼리와 국내용 tr_id 를 싣는다")
    func domesticQuoteCarriesTransactionID() throws {
        let endpoint = KISEndpoint.domesticQuote(code: "005930")
        let request = try endpoint.makeRequest()
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.host == "openapi.koreainvestment.com")
        #expect(components.port == 9443)
        #expect(components.path == "/uapi/domestic-stock/v1/quotations/inquire-price")
        #expect(queryValue(components, "FID_COND_MRKT_DIV_CODE") == "J")
        #expect(queryValue(components, "FID_INPUT_ISCD") == "005930")

        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "tr_id") == "FHKST01010100")
        #expect(request.value(forHTTPHeaderField: "custtype") == "P")
        #expect(endpoint.authentication == .kisAccessToken)
    }

    @Test("해외 현재가는 거래소·티커 쿼리와 해외용 tr_id 를 싣는다")
    func overseasQuoteCarriesTransactionID() throws {
        let endpoint = KISEndpoint.overseasQuote(exchange: .nasdaq, ticker: "AAPL")
        let request = try endpoint.makeRequest()
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/uapi/overseas-price/v1/quotations/price")
        #expect(queryValue(components, "EXCD") == "NAS")
        #expect(queryValue(components, "SYMB") == "AAPL")
        #expect(queryValue(components, "AUTH") == "")

        #expect(request.value(forHTTPHeaderField: "tr_id") == "HHDFS00000300")
        #expect(endpoint.authentication == .kisAccessToken)
    }

    @Test("환율 조회는 원/달러 종목코드와 한국 시간 기준 날짜 구간을 싣는다")
    func exchangeRateCarriesSeoulDateRange() throws {
        // from 은 UTC 로 7/26 15:30 이지만 한국 시간으로는 이미 7/27 이다 (시간대 처리 확인).
        let endpoint = KISEndpoint.exchangeRate(
            from: Date(timeIntervalSince1970: 1_785_079_800),
            to: Date(timeIntervalSince1970: 1_785_628_800)
        )
        let request = try endpoint.makeRequest()
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/uapi/overseas-price/v1/quotations/inquire-daily-chartprice")
        #expect(queryValue(components, "FID_COND_MRKT_DIV_CODE") == "X")
        #expect(queryValue(components, "FID_INPUT_ISCD") == "FX@KRW")
        #expect(queryValue(components, "FID_INPUT_DATE_1") == "20260727")
        #expect(queryValue(components, "FID_INPUT_DATE_2") == "20260802")
        #expect(queryValue(components, "FID_PERIOD_DIV_CODE") == "D")

        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "tr_id") == "FHKST03030100")
        #expect(endpoint.authentication == .kisAccessToken)
    }

    @Test("국내와 해외는 서로 다른 tr_id 를 쓴다")
    func transactionIDDiffersPerEndpoint() throws {
        let domestic = try KISEndpoint.domesticQuote(code: "069500").makeRequest()
        let overseas = try KISEndpoint
            .overseasQuote(exchange: .newYork, ticker: "KO")
            .makeRequest()

        #expect(
            domestic.value(forHTTPHeaderField: "tr_id")
                != overseas.value(forHTTPHeaderField: "tr_id")
        )
    }

    private func queryValue(_ components: URLComponents, _ name: String) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }
}
