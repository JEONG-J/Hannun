//
//  AppError.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation

/// 앱 전역 에러 타입. Loadable / ErrorHandler 양쪽에서 쓰인다.
/// Moya·SwiftData 같은 구체 기술을 알지 못한다 — 변환은 HannunData 가 담당한다.
public enum AppError: Error, Equatable, Sendable {
    case network(String)
    case decoding(String)
    case persistence(String)
    case validation(String)
    case unauthorized
    case unknown(String)
}

public extension AppError {
    /// 임의의 에러를 앱 전역 타입으로 좁힌다.
    ///
    /// `catch` 로 받은 값은 정적으로는 `any Error` 라서, Loadable 의 `.failed` 나 Alert 에
    /// 싣기 전에 반드시 이 변환을 거친다. 이미 `AppError` 면 그대로 통과시키고, 아니면
    /// 원문을 `unknown` 에 실어 사용자 문구와 진단 문자열을 분리한다.
    init(narrowing error: any Error) {
        self = error as? AppError ?? .unknown(String(describing: error))
    }

    /// Alert·인라인 에러 뷰에 그대로 노출하는 문구.
    ///
    /// 연관값에 사람이 읽을 문장을 싣는 케이스는 그대로 쓴다.
    /// `decoding`·`unknown` 은 타입 이름이나 raw error 설명 같은 진단 문자열이 들어오므로
    /// 사용자에게는 일반 문구로 바꿔 보여주고, 원문은 로그·디버깅용으로만 남긴다.
    var userMessage: String {
        switch self {
        case let .network(message), let .persistence(message), let .validation(message):
            message
        case .decoding:
            "정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        case .unauthorized:
            "시세 서버 인증에 실패했어요. API 키 설정을 확인해 주세요."
        case .unknown:
            "알 수 없는 문제가 발생했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}
