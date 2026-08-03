//
//  OnDeviceJournalContentWriter.swift
//  HannunData
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import FoundationModels
import HannunCore
import HannunDomain

/// 기기 안에서 도는 Apple Intelligence 로 매매일지 본문 초안을 쓴다 (JR-2).
///
/// 서버로 나가지 않는 게 이 기능의 전제다. 매매일지에는 무엇을 얼마에 얼마나 샀는지가
/// 그대로 적히므로, 초안을 만들자고 그 내용을 외부로 보낼 수는 없다. `SystemLanguageModel`
/// 은 온디바이스라서 재료가 기기를 벗어나지 않는다.
///
/// **숫자를 지어내지 않게 하는 것**이 지시문의 절반을 차지한다. 다른 글쓰기 보조와 달리
/// 여기서 지어낸 수익률 한 줄은 나중에 판단의 근거로 다시 읽히므로, 어색한 문장보다
/// 그럴듯한 거짓 숫자가 훨씬 비싼 실수다.
public struct OnDeviceJournalContentWriter: JournalContentWriterProtocol {
    // MARK: - Function

    public init() {}

    public func availability() async -> JournalContentAvailability {
        await Self.currentAvailability()
    }

    public func write(_ request: JournalContentRequest) async throws -> String {
        let availability = await Self.currentAvailability()
        guard let guidance = availability.guidance else {
            return try await Self.compose(request)
        }
        throw AppError.unavailable(guidance)
    }

    /// 못 쓰는 사유는 OS 판마다 늘 수 있어서 `switch` 로 다 세지 않는다. 우리가 **다르게
    /// 안내할** 두 가지만 집어내고 나머지는 "이 기기에선 못 쓴다" 한 갈래로 모은다 —
    /// 사용자가 할 일이 같은 상태를 굳이 갈라 봐야 문구만 늘어난다.
    @MainActor
    private static func currentAvailability() -> JournalContentAvailability {
        let availability = SystemLanguageModel.default.availability

        if case .available = availability { return .ready }
        if case .unavailable(.appleIntelligenceNotEnabled) = availability { return .intelligenceOff }
        if case .unavailable(.modelNotReady) = availability { return .modelNotReady }
        return .unsupportedDevice
    }

    /// 세션은 매번 새로 연다. 초안 만들기는 앞 대화를 이어받을 게 없는 한 방짜리 요청이라,
    /// 세션을 들고 있으면 재료가 바뀌어도 지난 초안이 문맥으로 남아 같은 문장이 돌아온다.
    @MainActor
    private static func compose(_ request: JournalContentRequest) async throws -> String {
        let session = LanguageModelSession(instructions: Constants.instructions)

        do {
            let response = try await session.respond(
                to: material(from: request),
                generating: JournalContentDraft.self,
                options: GenerationOptions(temperature: Constants.temperature)
            )
            return response.content.text
        } catch {
            // 프레임워크 에러 타입은 여기서 끊는다 (AppError 봉인 규칙). 원문은 진단용으로만
            // 남고 사용자에게는 `unknown` 의 일반 문구가 나간다.
            throw AppError.unknown(String(describing: error))
        }
    }

    /// 재료를 줄 단위 라벨로 세워 넘긴다. 빈 항목은 아예 빼야 모델이 "연결 종목: 없음" 을
    /// 문장으로 옮겨 적지 않는다.
    static func material(from request: JournalContentRequest) -> String {
        var lines: [String] = [
            "\(Constants.writtenAtLabel): \(formatted(request.writtenAt))",
        ]

        if !request.title.isEmpty {
            lines.insert("\(Constants.titleLabel): \(request.title)", at: 0)
        }
        if !request.holdingNames.isEmpty {
            let names = request.holdingNames.joined(separator: Constants.nameSeparator)
            lines.append("\(Constants.holdingLabel): \(names)")
        }
        if !request.memo.isEmpty {
            lines.append("\(Constants.memoLabel): \(request.memo)")
        }
        return lines.joined(separator: "\n")
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .long, time: .shortened).locale(Constants.locale)
        )
    }
}

/// 응답을 문자열 하나로 받지 않고 구조로 받는 이유는 서두("알겠습니다, 초안입니다:")를
/// 잘라 낼 필요가 없어서다. 필드 하나짜리 구조라도 모델이 채워야 할 칸이 정해지면 본문만
/// 돌아온다.
@Generable
struct JournalContentDraft {
    @Guide(description: "매매일지 본문. 한국어 평서문 3~5문장. 제목을 그대로 반복하지 않는다.")
    var text: String
}

fileprivate enum Constants {
    static let instructions = """
        당신은 개인 투자자가 남기는 매매일지의 본문을 대신 정리해 주는 조수입니다.

        - 한국어 평서문으로 3~5문장을 씁니다.
        - 사용자가 준 재료(제목·작성 시각·연결 종목·메모)에 있는 사실만 씁니다.
        - 가격·수익률·비중·수량 같은 숫자는 재료에 있는 것만 옮겨 적고, 없으면 지어내지 \
        않습니다. 모르는 값은 문장에서 빼세요.
        - 시장 전망을 단정하거나 매수·매도를 권하지 않습니다. 그때 왜 그렇게 판단했는지를 \
        1인칭으로 기록합니다.
        - 제목을 문장으로 되풀이하지 않습니다. 본문은 제목이 말하지 않은 이유를 적는 자리입니다.
        """
    /// 낮게 잡는다. 매매일지 본문은 표현의 다양함보다 재료에 붙어 있는 쪽이 값지다.
    static let temperature: Double = 0.4

    static let titleLabel = "제목"
    static let writtenAtLabel = "작성 시각"
    static let holdingLabel = "연결 종목"
    static let memoLabel = "메모"
    static let nameSeparator = ", "
    static let locale = Locale(identifier: "ko_KR")
}
