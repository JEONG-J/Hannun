import Foundation

/// 앱이 사용하는 HTTP 메서드.
/// 외부 API 는 시세 조회(GET)와 KIS 접근토큰 발급(POST) 둘뿐이라 두 케이스로 충분하다 (§11).
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}
