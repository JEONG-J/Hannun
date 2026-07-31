import Foundation

/// 화면 내 인라인 비동기 상태. 흐름 중단형 에러는 ErrorHandler 로 보낸다.
public enum Loadable<Value: Equatable>: Equatable, Sendable where Value: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(AppError)

    public var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}
