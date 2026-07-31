//
//  Loadable.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

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

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var error: AppError? {
        if case let .failed(error) = self { return error }
        return nil
    }

    /// 로딩·실패 상태는 그대로 두고 성공값만 화면 표시용 타입으로 바꾼다.
    public func map<Transformed: Equatable & Sendable>(
        _ transform: (Value) -> Transformed
    ) -> Loadable<Transformed> {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case let .loaded(value): .loaded(transform(value))
        case let .failed(error): .failed(error)
        }
    }
}
