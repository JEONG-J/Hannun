//
//  DraftJournalContentUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore

/// 매매일지 본문 초안을 만든다 (JR-2).
public protocol DraftJournalContentUseCaseProtocol: Sendable {
    /// 초안 기능을 화면에 내놓아도 되는지.
    func availability() async -> JournalContentAvailability

    func execute(_ request: JournalContentRequest) async throws -> String
}

public struct DraftJournalContentUseCase: DraftJournalContentUseCaseProtocol {
    // MARK: - Property

    private let contentWriter: any JournalContentWriterProtocol

    // MARK: - Function

    public init(contentWriter: any JournalContentWriterProtocol) {
        self.contentWriter = contentWriter
    }

    public func availability() async -> JournalContentAvailability {
        await contentWriter.availability()
    }

    /// 재료가 하나도 없으면 창구를 부르지 않는다.
    ///
    /// 매매일지는 **있었던 일**을 적는 기록이다. 제목도 종목도 메모도 없이 부르면 모델은
    /// 실제 매매와 아무 상관 없는 그럴듯한 문장을 지어낼 수밖에 없고, 그건 나중에 판단의
    /// 근거로 다시 읽힐 자리에 남으면 안 되는 종류의 글이다.
    public func execute(_ request: JournalContentRequest) async throws -> String {
        let normalized = Self.normalized(request)

        guard Self.hasMaterial(normalized) else {
            throw AppError.validation(Constants.noMaterialMessage)
        }

        let draft = try await contentWriter.write(normalized)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 빈 응답도 "성공" 으로 돌아온다. 그대로 통과시키면 화면에는 아무 일도 없었던 것처럼
        // 보이고, 사용자가 초안을 받아들이는 순간 쓰던 본문만 조용히 지워진다.
        guard !draft.isEmpty else {
            throw AppError.unknown(Constants.emptyDraftDiagnostic)
        }
        return draft
    }

    static func normalized(_ request: JournalContentRequest) -> JournalContentRequest {
        var normalized = request
        normalized.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.memo = request.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.holdingNames = request.holdingNames.filter { !$0.isEmpty }
        return normalized
    }

    static func hasMaterial(_ request: JournalContentRequest) -> Bool {
        !request.title.isEmpty || !request.memo.isEmpty || !request.holdingNames.isEmpty
    }
}

fileprivate enum Constants {
    static let noMaterialMessage = "무엇에 대한 일지인지 제목이나 메모로 한 줄만 알려 주세요."
    /// 사용자에게는 `AppError.unknown` 의 일반 문구가 나간다 — 빈 응답은 사용자가 고칠 수
    /// 있는 문제가 아니라서 시킬 일이 없다. 이 문자열은 로그·진단용이다.
    static let emptyDraftDiagnostic = "EmptyJournalContentDraft"
}
