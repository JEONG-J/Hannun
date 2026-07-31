import Foundation
import HannunCore

/// 요청에 인증 정보를 채워 넣는 쪽. 업비트처럼 인증이 없는 API 는 authorizer 없이 쓴다.
///
/// KIS 접근토큰 발급·갱신은 이 프로토콜 뒤에 숨는다 — `NetworkClient` 는 토큰의 생김새를 모른다.
protocol RequestAuthorizing: Sendable {
    /// 요청에 인증 헤더를 붙여 돌려준다.
    func authorize(_ request: URLRequest) async throws -> URLRequest

    /// 서버가 401 을 돌려줬을 때 보관 중인 토큰을 버린다. 재시도 직전에 호출된다.
    func invalidate() async
}

/// `URLSession` 기반 네트워크 클라이언트.
///
/// actor 인 이유는 **401 재시도 시퀀스를 직렬화**하기 위해서다. 동시 요청 여러 건이 한꺼번에
/// 401 을 받으면 토큰 무효화와 재발급이 서로 엉킬 수 있는데, 격리 안에서 처리하면 그 창이 닫힌다.
/// (§11.1·§11.2 가 요구하는 호출량 제한 게이트를 나중에 붙일 자리이기도 하다.)
///
/// - Note: actor 는 재진입 가능하므로 요청이 직렬화되지는 않는다.
///   `session.data(for:)` 에서 중단되는 동안 다른 요청이 들어와 함께 진행된다.
actor NetworkClient {
    private let session: URLSession
    private let authorizer: (any RequestAuthorizing)?
    private let maxRetryCount: Int

    init(
        session: URLSession = .shared,
        authorizer: (any RequestAuthorizing)? = nil,
        maxRetryCount: Int = 1
    ) {
        self.session = session
        self.authorizer = authorizer
        self.maxRetryCount = maxRetryCount
    }

    /// 응답을 `Sendable` 값으로 디코딩해 돌려준다.
    func send<Value: Decodable & Sendable>(
        _ endpoint: some Endpoint,
        as _: Value.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Value {
        let data = try await data(for: endpoint)
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw AppError.decoding("\(Value.self) 응답을 해석하지 못했습니다.")
        }
    }

    /// 원시 응답 본문을 돌려준다. 디코딩 스키마가 확정되지 않은 엔드포인트에 쓴다.
    func data(for endpoint: some Endpoint) async throws -> Data {
        try await perform(endpoint, retryCount: 0)
    }

    private func perform(_ endpoint: some Endpoint, retryCount: Int) async throws -> Data {
        var request = try endpoint.makeRequest()

        if endpoint.authentication != .none {
            guard let authorizer else {
                throw AppError.unauthorized
            }
            request = try await authorizer.authorize(request)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError(transport: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("HTTP 응답이 아닙니다.")
        }

        // 토큰 만료. 한 번만 무효화 후 재시도하고, 그래도 401 이면 재로그인 흐름으로 넘긴다.
        if httpResponse.statusCode == 401, endpoint.authentication != .none {
            guard retryCount < maxRetryCount else {
                throw AppError.unauthorized
            }
            await authorizer?.invalidate()
            return try await perform(endpoint, retryCount: retryCount + 1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
