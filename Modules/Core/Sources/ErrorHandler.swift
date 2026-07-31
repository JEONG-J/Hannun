//
//  ErrorHandler.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import Observation

/// 에러가 어디서 났는지 남기는 진단 정보. 재시도 경로가 있으면 Alert 에 재시도 버튼이 붙는다.
public struct ErrorContext: Sendable {
    public let feature: String
    public let action: String
    public let retryAction: (@MainActor @Sendable () async -> Void)?

    public init(
        feature: String,
        action: String,
        retryAction: (@MainActor @Sendable () async -> Void)? = nil
    ) {
        self.feature = feature
        self.action = action
        self.retryAction = retryAction
    }
}

/// Alert 로 떠 있는 에러 한 건. 같은 에러가 다시 와도 새 Alert 로 보이도록 매번 새 id 를 만든다.
public struct PresentedError: Identifiable, Sendable {
    public let id = UUID()
    public let error: AppError
    public let context: ErrorContext

    public var canRetry: Bool { context.retryAction != nil }

    public init(error: AppError, context: ErrorContext) {
        self.error = error
        self.context = context
    }
}

/// 흐름을 끊는 에러를 전역 Alert 한 건으로 모으는 지점.
/// 화면 안에 머무는 상태(로딩 실패·검증 실패)는 Loadable 이 맡는다.
@MainActor
@Observable
public final class ErrorHandler {
    // MARK: - Property

    public private(set) var presentedError: PresentedError?

    // MARK: - Function

    public init() {}

    /// AppError 가 아닌 에러도 여기서 한 번에 Core 타입으로 좁힌다.
    public func handle(_ error: any Error, context: ErrorContext) {
        presentedError = PresentedError(error: AppError(narrowing: error), context: context)
    }

    public func dismiss() {
        presentedError = nil
    }

    /// 재시도 경로가 없으면 표시 상태를 그대로 둔다 — Alert 에 재시도 버튼도 없다.
    public func retry() async {
        guard let retryAction = presentedError?.context.retryAction else { return }
        presentedError = nil
        await retryAction()
    }
}
