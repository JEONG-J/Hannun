//
//  AppErrorTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 8/1/26.
//

import Testing
@testable import HannunCore

@Suite("AppError 좁히기")
struct AppErrorNarrowingTests {
    private enum SampleError: Error {
        case thrownByThirdParty
    }

    @Test("이미 AppError 면 그대로 통과시킨다")
    func keepsAppError() {
        let original = AppError.validation("제목을 입력해 주세요.")

        #expect(AppError(narrowing: original) == original)
    }

    @Test("다른 에러는 원문을 실어 unknown 이 된다")
    func wrapsForeignError() {
        let narrowed = AppError(narrowing: SampleError.thrownByThirdParty)

        #expect(narrowed == .unknown(String(describing: SampleError.thrownByThirdParty)))
    }

    @Test("진단 문자열은 사용자 문구로 새어 나가지 않는다")
    func hidesDiagnosticStringFromUserMessage() {
        let narrowed = AppError(narrowing: SampleError.thrownByThirdParty)

        #expect(!narrowed.userMessage.contains("thrownByThirdParty"))
    }
}
