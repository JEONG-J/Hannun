//
//  NetworkClientTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Synchronization
import Testing
@testable import HannunData

private struct EchoEndpoint: Endpoint {
    var baseURL = URL(string: "https://api.example.com")!
    var path = "/v1/echo"
    var authentication: EndpointAuthentication = .none
}

private struct EchoBody: Decodable, Equatable, Sendable {
    let message: String
}

/// 토큰을 붙이고 무효화 횟수를 세는 스텁. 401 재시도 시퀀스를 관찰하는 용도다.
private actor SpyAuthorizer: RequestAuthorizing {
    private(set) var authorizeCount = 0
    private(set) var invalidateCount = 0

    func authorize(_ request: URLRequest) async throws -> URLRequest {
        authorizeCount += 1
        var authorized = request
        authorized.setValue("Bearer token-\(authorizeCount)", forHTTPHeaderField: "Authorization")
        return authorized
    }

    func invalidate() async {
        invalidateCount += 1
    }
}

@Suite("NetworkClient")
struct NetworkClientTests {
    @Test("200 응답을 디코딩해서 돌려준다")
    func decodesSuccessResponse() async throws {
        let session = StubURLProtocol.makeSession { _ in .json(#"{"message":"안녕"}"#) }
        defer { StubURLProtocol.tearDown(session) }

        let value = try await NetworkClient(session: session)
            .send(EchoEndpoint(), as: EchoBody.self)

        #expect(value == EchoBody(message: "안녕"))
    }

    @Test("서버 메시지가 있으면 에러 문구에 담는다")
    func surfacesServerMessage() async throws {
        let session = StubURLProtocol.makeSession { _ in
            .json(#"{"error":{"message":"존재하지 않는 마켓입니다."}}"#, statusCode: 404)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.network("존재하지 않는 마켓입니다.")) {
            try await NetworkClient(session: session).send(EchoEndpoint(), as: EchoBody.self)
        }
    }

    @Test("깨진 JSON 은 decoding 에러로 바꾼다")
    func mapsMalformedJSONToDecodingError() async throws {
        let session = StubURLProtocol.makeSession { _ in .json("깨진 응답") }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.self) {
            try await NetworkClient(session: session).send(EchoEndpoint(), as: EchoBody.self)
        }
    }

    @Test("인증이 필요한데 authorizer 가 없으면 즉시 unauthorized 다")
    func requiresAuthorizerForAuthenticatedEndpoint() async throws {
        let session = StubURLProtocol.makeSession { _ in .json("{}") }
        defer { StubURLProtocol.tearDown(session) }

        var endpoint = EchoEndpoint()
        endpoint.authentication = .kisAccessToken

        await #expect(throws: AppError.unauthorized) {
            try await NetworkClient(session: session).data(for: endpoint)
        }
    }

    @Test("401 이면 토큰을 무효화하고 한 번만 재시도한다")
    func retriesOnceAfterUnauthorized() async throws {
        let requestCount = Mutex(0)
        let session = StubURLProtocol.makeSession { _ in
            requestCount.withLock { $0 += 1 }
            return .json("{}", statusCode: 401)
        }
        defer { StubURLProtocol.tearDown(session) }

        var endpoint = EchoEndpoint()
        endpoint.authentication = .kisAccessToken
        let authorizer = SpyAuthorizer()
        let client = NetworkClient(session: session, authorizer: authorizer)

        await #expect(throws: AppError.unauthorized) {
            try await client.data(for: endpoint)
        }

        #expect(requestCount.withLock { $0 } == 2)
        #expect(await authorizer.invalidateCount == 1)
        #expect(await authorizer.authorizeCount == 2)
    }

    @Test("인증이 없는 엔드포인트의 401 은 재시도하지 않는다")
    func doesNotRetryUnauthenticatedEndpoint() async throws {
        let requestCount = Mutex(0)
        let session = StubURLProtocol.makeSession { _ in
            requestCount.withLock { $0 += 1 }
            return .json("{}", statusCode: 401)
        }
        defer { StubURLProtocol.tearDown(session) }

        await #expect(throws: AppError.unauthorized) {
            try await NetworkClient(session: session).data(for: EchoEndpoint())
        }

        #expect(requestCount.withLock { $0 } == 1)
    }

    @Test("authorizer 가 넣은 헤더가 실제 요청에 실린다")
    func appliesAuthorizationHeader() async throws {
        let header = Mutex<String?>(nil)
        let session = StubURLProtocol.makeSession { request in
            header.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return .json("{}")
        }
        defer { StubURLProtocol.tearDown(session) }

        var endpoint = EchoEndpoint()
        endpoint.authentication = .kisAccessToken
        _ = try await NetworkClient(session: session, authorizer: SpyAuthorizer())
            .data(for: endpoint)

        #expect(header.withLock { $0 } == "Bearer token-1")
    }
}
