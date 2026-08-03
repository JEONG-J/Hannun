//
//  DraftJournalContentUseCaseTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("DraftJournalContentUseCase")
struct DraftJournalContentUseCaseTests {
    private let writtenAt = SampleRecords.day(2026, 7, 25)

    /// 매매일지는 있었던 일을 적는 기록이다. 재료가 없으면 모델은 실제 매매와 무관한 문장을
    /// 지어낼 수밖에 없으므로 창구를 부르는 것 자체를 막는다.
    @Test("재료가 하나도 없으면 창구를 부르지 않는다")
    func rejectsRequestWithoutMaterial() async {
        let writer = SpyJournalContentWriter()
        let useCase = DraftJournalContentUseCase(contentWriter: writer)

        await #expect(throws: AppError.self) {
            try await useCase.execute(makeRequest())
        }
        #expect(await writer.callCount == 0)
    }

    @Test("공백만 적은 재료는 없는 것으로 본다")
    func treatsBlankMaterialAsEmpty() async {
        let writer = SpyJournalContentWriter()
        let useCase = DraftJournalContentUseCase(contentWriter: writer)

        await #expect(throws: AppError.self) {
            try await useCase.execute(makeRequest(title: "   ", memo: "\n"))
        }
        #expect(await writer.callCount == 0)
    }

    @Test("메모만 있어도 초안을 청한다")
    func acceptsMemoOnlyMaterial() async throws {
        let useCase = DraftJournalContentUseCase(
            contentWriter: SpyJournalContentWriter(draft: .success("환율 부담에 비중을 줄였다."))
        )

        let draft = try await useCase.execute(makeRequest(memo: "환율 부담"))

        #expect(draft == "환율 부담에 비중을 줄였다.")
    }

    /// 앞뒤 공백을 털어 두지 않으면 본문 첫 줄이 빈 줄로 시작한다.
    @Test("초안의 앞뒤 공백을 털어 낸다")
    func trimsDraftWhitespace() async throws {
        let useCase = DraftJournalContentUseCase(
            contentWriter: SpyJournalContentWriter(draft: .success("\n  비중을 줄였다.  \n"))
        )

        let draft = try await useCase.execute(makeRequest(title: "반도체 비중 축소"))

        #expect(draft == "비중을 줄였다.")
    }

    /// 빈 응답도 "성공" 으로 돌아온다. 그대로 통과시키면 받아들이는 순간 본문만 지워진다.
    @Test("빈 응답은 실패로 되돌린다")
    func rejectsEmptyDraft() async {
        let useCase = DraftJournalContentUseCase(
            contentWriter: SpyJournalContentWriter(draft: .success("   \n  "))
        )

        await #expect(throws: AppError.self) {
            try await useCase.execute(makeRequest(title: "반도체 비중 축소"))
        }
    }

    /// 창구에 넘기기 전에 다듬는다 — 공백째 넘기면 프롬프트에 빈 라벨 줄이 남는다.
    @Test("창구에는 다듬은 재료가 간다")
    func passesNormalizedMaterialToWriter() async throws {
        let writer = SpyJournalContentWriter()
        let useCase = DraftJournalContentUseCase(contentWriter: writer)

        _ = try await useCase.execute(
            makeRequest(title: "  반도체 비중 축소  ", holdingNames: ["삼성전자", ""], memo: " 환율 ")
        )

        let request = try #require(await writer.lastRequest)
        #expect(request.title == "반도체 비중 축소")
        #expect(request.memo == "환율")
        #expect(request.holdingNames == ["삼성전자"])
    }

    @Test("가용 상태는 창구 값을 그대로 전한다")
    func forwardsWriterAvailability() async {
        let useCase = DraftJournalContentUseCase(
            contentWriter: SpyJournalContentWriter(readiness: .modelNotReady)
        )

        #expect(await useCase.availability() == .modelNotReady)
    }

    // MARK: - Function

    private func makeRequest(
        title: String = "",
        holdingNames: [String] = [],
        memo: String = ""
    ) -> JournalContentRequest {
        JournalContentRequest(
            title: title,
            writtenAt: writtenAt,
            holdingNames: holdingNames,
            memo: memo
        )
    }
}

/// 초안 창구 대역. 실제 구현은 HannunData 의 FoundationModels 구현체라 여기서 부를 수 없다.
private actor SpyJournalContentWriter: JournalContentWriterProtocol {
    private let readiness: JournalContentAvailability
    private let draft: Result<String, AppError>

    private(set) var lastRequest: JournalContentRequest?
    private(set) var callCount = 0

    init(
        readiness: JournalContentAvailability = .ready,
        draft: Result<String, AppError> = .success("초안 본문")
    ) {
        self.readiness = readiness
        self.draft = draft
    }

    func availability() async -> JournalContentAvailability {
        readiness
    }

    func write(_ request: JournalContentRequest) async throws -> String {
        callCount += 1
        lastRequest = request
        return try draft.get()
    }
}
