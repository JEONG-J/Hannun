//
//  AlertPromptTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
@testable import HannunCore

@Suite("AlertPrompt")
@MainActor
struct AlertPromptTests {
    @Test("기본값은 취소 라벨·비파괴·메시지 없음이다")
    func defaultsAreNonDestructive() {
        let prompt = AlertPrompt(title: "삭제 확인", confirmTitle: "삭제") {}

        #expect(prompt.cancelTitle == "취소")
        #expect(prompt.isDestructive == false)
        #expect(prompt.message == nil)
    }

    @Test("같은 내용이라도 인스턴스마다 id 가 다르다")
    func idIsUniquePerInstance() {
        let firstPrompt = AlertPrompt(title: "삭제 확인", confirmTitle: "삭제") {}
        let secondPrompt = AlertPrompt(title: "삭제 확인", confirmTitle: "삭제") {}

        #expect(firstPrompt.id != secondPrompt.id)
    }

    @Test("확인 액션이 실행된다")
    func confirmActionRuns() async {
        await confirmation("확인 액션 호출") { confirmed in
            let prompt = AlertPrompt(
                title: "종목 삭제",
                message: "삭제하면 되돌릴 수 없어요.",
                confirmTitle: "삭제",
                isDestructive: true,
                confirmAction: { confirmed() }
            )

            prompt.confirmAction()
        }
    }
}
