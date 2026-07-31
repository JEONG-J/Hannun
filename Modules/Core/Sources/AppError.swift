import Foundation

/// 앱 전역 에러 타입. Loadable / ErrorHandler 양쪽에서 쓰인다.
/// Moya·SwiftData 같은 구체 기술을 알지 못한다 — 변환은 HannunData 가 담당한다 (§9.5).
public enum AppError: Error, Equatable, Sendable {
    case network(String)
    case decoding(String)
    case persistence(String)
    case validation(String)
    case unauthorized
    case unknown(String)
}
