//
//  ErrorHandlerTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
@testable import HannunCore

@Suite("ErrorHandler")
@MainActor
struct ErrorHandlerTests {
    private enum SampleError: Error {
        case thrownByThirdParty
    }

    private func makeContext(
        retryAction: (@MainActor @Sendable () async -> Void)? = nil
    ) -> ErrorContext {
        ErrorContext(feature: "Portfolio", action: "refreshTapped", retryAction: retryAction)
    }

    @Test("AppError 는 그대로 보존한다")
    func keepsAppError() throws {
        let handler = ErrorHandler()
        handler.handle(AppError.network("timeout"), context: makeContext())

        let presented = try #require(handler.presentedError)
        #expect(presented.error == .network("timeout"))
        #expect(presented.context.feature == "Portfolio")
    }

    @Test("AppError 가 아닌 에러는 unknown 으로 좁힌다")
    func wrapsForeignErrorAsUnknown() throws {
        let handler = ErrorHandler()
        handler.handle(SampleError.thrownByThirdParty, context: makeContext())

        let presented = try #require(handler.presentedError)
        #expect(presented.error == .unknown(String(describing: SampleError.thrownByThirdParty)))
    }

    @Test("재시도 경로가 없으면 canRetry 가 거짓이다")
    func withoutRetryActionCannotRetry() throws {
        let handler = ErrorHandler()
        handler.handle(AppError.unauthorized, context: makeContext())

        let presented = try #require(handler.presentedError)
        #expect(presented.canRetry == false)
    }

    @Test("dismiss 는 표시 상태를 비운다")
    func dismissClearsPresentedError() {
        let handler = ErrorHandler()
        handler.handle(AppError.unauthorized, context: makeContext())
        handler.dismiss()

        #expect(handler.presentedError == nil)
    }

    @Test("retry 는 재시도 액션을 실행하고 Alert 을 닫는다")
    func retryRunsActionAndCloses() async {
        let handler = ErrorHandler()

        await confirmation("재시도 액션 호출") { retried in
            handler.handle(AppError.network("timeout"), context: makeContext(retryAction: {
                retried()
            }))
            #expect(handler.presentedError?.canRetry == true)

            await handler.retry()
        }

        #expect(handler.presentedError == nil)
    }

    @Test("재시도 경로가 없으면 retry 는 표시 상태를 유지한다")
    func retryWithoutActionKeepsPresentedError() async {
        let handler = ErrorHandler()
        handler.handle(AppError.unauthorized, context: makeContext())

        await handler.retry()

        #expect(handler.presentedError != nil)
    }
}
