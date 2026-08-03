//
//  JournalContentWriterProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation

/// 매매일지 본문 초안을 지어 주는 창구. 실제 구현(`OnDeviceJournalContentWriter`)은
/// HannunData 에 있다 (봉인 규칙) — Domain 은 어떤 모델이 도는지 알지 않는다.
///
/// **만들어 주기만 하고 어디에도 반영하지 않는다.** 초안은 사용자가 읽고 받아들여야 본문이
/// 되므로 이 창구의 결과가 화면을 건너뛰고 저장소로 갈 길은 없다.
public protocol JournalContentWriterProtocol: Sendable {
    /// 지금 초안을 만들 수 있는지. 기기·설정·모델 준비 상태에 따라 앱이 떠 있는 동안에도 바뀐다.
    func availability() async -> JournalContentAvailability

    /// 초안 본문 한 덩어리.
    func write(_ request: JournalContentRequest) async throws -> String
}

/// 초안 생성기를 지금 쓸 수 있는지, 못 쓴다면 왜인지.
///
/// 못 쓰는 이유를 하나로 뭉치지 않는 건 사용자가 할 일이 서로 다르기 때문이다 — 설정에서
/// 켜면 되는 경우와 기기를 바꿔야 하는 경우를 같은 문구로 안내하면 둘 다 막다른 길이 된다.
public enum JournalContentAvailability: Sendable, Equatable {
    /// 지금 쓸 수 있다.
    case ready
    /// 이 기기가 지원 대상이 아니다. 사용자가 할 수 있는 일이 없다.
    case unsupportedDevice
    /// 기기는 되는데 Apple Intelligence 가 꺼져 있다. 설정에서 켜면 된다.
    case intelligenceOff
    /// 켜져 있고 모델을 준비하는 중이다. 기다리면 된다.
    case modelNotReady

    public var isReady: Bool { self == .ready }

    /// 못 쓰는 이유를 사용자 문장으로. `AppError.userMessage` 와 같은 자리의 값이다.
    public var guidance: String? {
        switch self {
        case .ready:
            nil
        case .unsupportedDevice:
            "이 기기에서는 Apple Intelligence를 쓸 수 없어요."
        case .intelligenceOff:
            "설정에서 Apple Intelligence를 켜면 본문 초안을 만들 수 있어요."
        case .modelNotReady:
            "Apple Intelligence를 준비하는 중이에요. 잠시 후 다시 시도해 주세요."
        }
    }
}

/// 초안을 쓸 때 넘기는 재료. 작성 화면이 이미 들고 있는 값에 메모 한 줄을 더한 것이다.
///
/// 일지 엔티티(`JournalRecord`)를 그대로 넘기지 않는다. 저장 전의 화면 상태에는 식별자나
/// 저장 시각처럼 글을 쓰는 데 쓸모없는 값이 섞여 있고, 반대로 메모는 일지에 남지 않는
/// 재료라서 엔티티에 자리가 없다.
public struct JournalContentRequest: Sendable, Equatable {
    /// 일지 제목. 무엇에 대한 기록인지 가장 짧게 말해 준다.
    public var title: String
    /// 매매가 일어난 시각.
    public var writtenAt: Date
    /// 연결한 보유 종목 이름.
    public var holdingNames: [String]
    /// 사용자가 남긴 메모. "환율 부담, 비중 축소" 처럼 토막이어도 된다.
    public var memo: String

    public init(
        title: String,
        writtenAt: Date,
        holdingNames: [String],
        memo: String
    ) {
        self.title = title
        self.writtenAt = writtenAt
        self.holdingNames = holdingNames
        self.memo = memo
    }
}
