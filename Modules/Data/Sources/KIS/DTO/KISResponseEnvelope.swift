//
//  KISResponseEnvelope.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// KIS 응답을 감싸는 공통 봉투.
///
/// **HTTP 200 이어도 `rt_cd` 가 `0` 이 아니면 실패다.** 상태 코드만 보고 넘기면 조회 실패를
/// 정상 응답으로 착각해 빈 값을 그대로 화면에 올리게 된다.
struct KISResponseEnvelope<Output: Decodable & Sendable>: Decodable, Sendable {
    /// 성공 코드. KIS 는 실패 시 `1` 을 준다.
    static var successReturnCode: String { "0" }

    let returnCode: String
    let messageCode: String?
    let message: String?
    let output: Output?

    private enum CodingKeys: String, CodingKey {
        case returnCode = "rt_cd"
        case messageCode = "msg_cd"
        case message = "msg1"
        case output
    }

    /// 성공 응답의 본문을 꺼낸다. 실패면 서버가 준 사유를 그대로 올린다.
    func requireOutput() throws -> Output {
        guard returnCode == Self.successReturnCode else {
            throw AppError.network(serverMessage ?? "시세를 조회하지 못했습니다.")
        }
        guard let output else {
            throw AppError.decoding("KIS 응답에 output 이 없습니다.")
        }
        return output
    }

    /// KIS 는 `msg1` 을 고정 폭으로 채워 보내 뒤쪽에 공백이 붙는다.
    private var serverMessage: String? {
        guard let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }

        return trimmed
    }
}
