//
//  KISClientTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Synchronization
import Testing
@testable import HannunData

/// 토큰 발급을 타지 않고 고정 헤더만 붙이는 인증기.
private struct FixedAuthorizer: RequestAuthorizing {
    let accessToken: String

    func authorize(_ request: URLRequest) async throws -> URLRequest {
        var authorized = request
        authorized.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        authorized.setValue("test-app-key", forHTTPHeaderField: "appkey")
        authorized.setValue("test-app-secret", forHTTPHeaderField: "appsecret")
        return authorized
    }

    func invalidate() async {}
}

@Suite("KISClient")
struct KISClientTests {
    private static let domesticJSON = """
    {
      "rt_cd": "0",
      "msg_cd": "MCA00000",
      "msg1": "정상처리 되었습니다.",
      "output": { "stck_prpr": "70800", "prdy_ctrt": "1.28" }
    }
    """

    private static let overseasJSON = """
    {
      "rt_cd": "0",
      "msg_cd": "MCA00000",
      "msg1": "정상처리 되었습니다.",
      "output": { "last": "228.52", "rate": "-0.41" }
    }
    """

    /// 실사용 간격(0.5초)을 그대로 쓰면 테스트가 요청 수만큼 느려져 0 으로 둔다.
    /// 간격이 지켜지는지는 `spacesRequestsByInterval` 에서 따로 본다.
    private func makeClient(
        requestInterval: TimeInterval = 0,
        handler: @escaping StubURLProtocol.Handler
    ) -> (KISClient, URLSession) {
        let session = StubURLProtocol.makeSession(handler: handler)
        let client = KISClient(
            session: session,
            authorizer: FixedAuthorizer(accessToken: "token"),
            requestInterval: requestInterval
        )
        return (client, session)
    }

    @Test("국내 종목 현재가는 원화다")
    func fetchesDomesticPriceInKRW() async throws {
        let (client, session) = makeClient { _ in .json(Self.domesticJSON) }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await client.price(for: .domesticEquity(code: "005930"))

        #expect(price == .krw(70_800))
    }

    @Test("해외 종목 현재가는 달러다")
    func fetchesOverseasPriceInUSD() async throws {
        let (client, session) = makeClient { _ in .json(Self.overseasJSON) }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await client.price(
            for: .overseasEquity(exchange: .nasdaq, ticker: "AAPL")
        )

        #expect(price == .usd(Decimal(string: "228.52")!))
    }

    @Test("소수점 가격이 부동소수 오차 없이 그대로 들어온다")
    func preservesDecimalPrecision() async throws {
        let json = """
        {"rt_cd":"0","output":{"last":"0.1234","rate":"0.0"}}
        """
        let (client, session) = makeClient { _ in .json(json) }
        defer { StubURLProtocol.tearDown(session) }

        let price = try await client.price(
            for: .overseasEquity(exchange: .nasdaq, ticker: "PENNY")
        )

        #expect(price.amount == Decimal(string: "0.1234")!)
    }

    @Test("인증 헤더 4종이 실제 요청에 실린다")
    func appliesAuthenticationHeaders() async throws {
        let headers = Mutex<[String: String]>([:])
        let (client, session) = makeClient { request in
            headers.withLock { captured in
                for field in ["authorization", "appkey", "appsecret", "tr_id"] {
                    captured[field] = request.value(forHTTPHeaderField: field)
                }
            }
            return .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        _ = try await client.price(for: .domesticEquity(code: "005930"))

        let captured = headers.withLock { $0 }
        #expect(captured["authorization"] == "Bearer token")
        #expect(captured["appkey"] == "test-app-key")
        #expect(captured["appsecret"] == "test-app-secret")
        #expect(captured["tr_id"] == "FHKST01010100")
    }

    @Test("HTTP 200 이라도 rt_cd 가 0 이 아니면 실패다")
    func treatsNonZeroReturnCodeAsFailure() async throws {
        let json = """
        {"rt_cd":"1","msg_cd":"OPSQ0001","msg1":"조회할 수 없는 종목입니다.   ","output":null}
        """
        let (client, session) = makeClient { _ in .json(json) }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.network("조회할 수 없는 종목입니다.")) {
            try await client.price(for: .domesticEquity(code: "000000"))
        }
    }

    @Test("현재가가 빈 문자열이면 조회 실패로 다룬다")
    func treatsEmptyPriceAsFailure() async throws {
        let (client, session) = makeClient { _ in
            .json(#"{"rt_cd":"0","output":{"last":"","rate":""}}"#)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.self) {
            try await client.price(for: .overseasEquity(exchange: .nasdaq, ticker: "NONE"))
        }
    }

    @Test("배치 조회는 종목마다 요청을 나눠 보낸다")
    func batchSendsOneRequestPerSymbol() async throws {
        let requestCount = Mutex(0)
        let (client, session) = makeClient { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let prices = try await client.prices(for: [
            "005930": .domesticEquity(code: "005930"),
            "000660": .domesticEquity(code: "000660"),
            "069500": .domesticEquity(code: "069500"),
        ])

        #expect(prices.count == 3)
        #expect(requestCount.withLock { $0 } == 3)
    }

    @Test("배치 중 일부가 실패해도 나머지는 그대로 돌려준다")
    func batchDropsFailedSymbolsOnly() async throws {
        let (client, session) = makeClient { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "FID_INPUT_ISCD" }?.value

            guard query == "000660" else { return .json(Self.domesticJSON) }
            return .json(#"{"rt_cd":"1","msg1":"조회할 수 없는 종목입니다."}"#)
        }
        defer { StubURLProtocol.tearDown(session) }

        let prices = try await client.prices(for: [
            "005930": .domesticEquity(code: "005930"),
            "000660": .domesticEquity(code: "000660"),
        ])

        #expect(prices.count == 1)
        #expect(prices["005930"] == .krw(70_800))
        #expect(prices["000660"] == nil)
    }

    @Test("배치가 전부 실패하면 첫 에러를 올린다")
    func batchThrowsWhenEveryRequestFails() async throws {
        let (client, session) = makeClient { _ in
            .json(#"{"msg_cd":"OPSQ0001","msg1":"서비스 점검 중입니다."}"#, statusCode: 500)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.network("서비스 점검 중입니다.")) {
            try await client.prices(for: [
                "005930": .domesticEquity(code: "005930"),
                "000660": .domesticEquity(code: "000660"),
            ])
        }
    }

    @Test("동시에 요청해도 출발 시각을 간격만큼 벌린다")
    func spacesRequestsByInterval() async throws {
        let interval: TimeInterval = 0.05
        let startTimes = Mutex<[Date]>([])
        let (client, session) = makeClient(requestInterval: interval) { _ in
            startTimes.withLock { $0.append(Date()) }
            return .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let targets = Dictionary(
            uniqueKeysWithValues: (0..<6).map {
                (String(format: "%06d", $0), KISQuoteTarget.domesticEquity(code: "005930"))
            }
        )
        let prices = try await client.prices(for: targets)

        #expect(prices.count == 6)

        // 스케줄러 지연은 간격을 늘리기만 하므로 하한만 본다.
        let sorted = startTimes.withLock { $0.sorted() }
        let gaps = zip(sorted, sorted.dropFirst()).map { $1.timeIntervalSince($0) }
        #expect(gaps.allSatisfy { $0 >= interval * 0.8 })
    }

    @Test("빈 목록은 네트워크를 타지 않는다")
    func skipsNetworkForEmptyTargets() async throws {
        let requestCount = Mutex(0)
        let (client, session) = makeClient { _ in
            requestCount.withLock { $0 += 1 }
            return .json(Self.domesticJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        #expect(try await client.prices(for: [:]).isEmpty)
        #expect(requestCount.withLock { $0 } == 0)
    }
}
