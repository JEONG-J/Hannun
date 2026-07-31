//
//  StubURLProtocol.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import Synchronization

/// 스텁이 돌려줄 HTTP 응답.
public struct StubResponse: Sendable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int = 200, data: Data = Data()) {
        self.statusCode = statusCode
        self.data = data
    }

    /// JSON 문자열로 200 응답을 만든다.
    public static func json(_ string: String, statusCode: Int = 200) -> StubResponse {
        StubResponse(statusCode: statusCode, data: Data(string.utf8))
    }
}

public enum StubURLProtocolError: Error, Sendable {
    /// 세션에 등록된 핸들러를 찾지 못했다.
    case handlerNotFound
}

/// `URLSession` 요청을 가로채 미리 정한 응답을 돌려주는 테스트용 프로토콜.
///
/// 네트워크 계층이 테스트의 존재를 알 필요가 없다는 점이 스터빙 API 를 프로덕션 코드에
/// 심는 방식보다 낫다. 핸들러를 **세션마다 따로** 보관하므로 Swift Testing 의 기본
/// 병렬 실행에서도 테스트끼리 간섭하지 않는다.
///
/// ```swift
/// let session = StubURLProtocol.makeSession { _ in .json(#"[{"market":"KRW-BTC"}]"#) }
/// defer { StubURLProtocol.tearDown(session) }
/// ```
public final class StubURLProtocol: URLProtocol {
    public typealias Handler = @Sendable (URLRequest) throws -> StubResponse

    private static let sessionIDHeader = "X-Hannun-Stub-Session"
    private static let handlers = Mutex<[String: Handler]>([:])

    /// 스텁이 걸린 세션을 만든다. 세션마다 고유 키를 쓰므로 병렬 테스트에 안전하다.
    public static func makeSession(handler: @escaping Handler) -> URLSession {
        let sessionID = UUID().uuidString
        handlers.withLock { $0[sessionID] = handler }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [sessionIDHeader: sessionID]
        return URLSession(configuration: configuration)
    }

    /// 세션에 묶인 핸들러를 버린다. 테스트 종료 시 호출한다.
    public static func tearDown(_ session: URLSession) {
        guard
            let sessionID = session.configuration.httpAdditionalHeaders?[sessionIDHeader] as? String
        else { return }

        handlers.withLock { $0[sessionID] = nil }
        session.invalidateAndCancel()
    }

    // MARK: - URLProtocol

    public override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: sessionIDHeader) != nil
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        guard
            let sessionID = request.value(forHTTPHeaderField: Self.sessionIDHeader),
            let handler = Self.handlers.withLock({ $0[sessionID] }),
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: StubURLProtocolError.handlerNotFound)
            return
        }

        do {
            let stub = try handler(request)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: StubURLProtocolError.handlerNotFound)
                return
            }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    public override func stopLoading() {}
}
