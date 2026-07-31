//
//  AppError+Transport.swift
//  HannunData
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore

/// 전송 계층 에러 → AppError 변환.
/// Core 는 URLSession 을 몰라야 하므로 변환 지점을 HannunData 에 둔다.
extension AppError {
    /// `URLSession` 이 던진 에러를 앱 에러로 바꾼다.
    init(transport error: any Error) {
        switch error {
        case is CancellationError:
            self = .network("요청이 취소되었습니다.")

        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                self = .network("인터넷 연결을 확인해주세요.")
            case .timedOut:
                self = .network("서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요.")
            case .cancelled:
                self = .network("요청이 취소되었습니다.")
            default:
                self = .network(urlError.localizedDescription)
            }

        default:
            self = .network(error.localizedDescription)
        }
    }

    /// 2xx 가 아닌 HTTP 응답을 앱 에러로 바꾼다.
    /// 서버가 본문에 메시지를 실어 보냈다면 그걸 우선 노출한다.
    init(statusCode: Int, data: Data?) {
        if Self.indicatesExpiredCredential(statusCode: statusCode, data: data) {
            self = .unauthorized
            return
        }

        if let message = Self.serverMessage(from: data) {
            self = .network(message)
            return
        }

        switch statusCode {
        case 429:
            self = .network("요청이 너무 잦습니다. 잠시 후 다시 시도해주세요.")
        case 400...499:
            self = .network("요청을 처리할 수 없습니다. (\(statusCode))")
        case 500...599:
            self = .network("서버에 일시적인 오류가 발생했습니다. (\(statusCode))")
        default:
            self = .network("알 수 없는 응답입니다. (\(statusCode))")
        }
    }

    /// 접근토큰을 다시 받아 재시도해야 하는 응답인지 판정한다.
    ///
    /// **KIS 는 토큰이 만료돼도 401 을 주지 않는 경우가 있다** — 200 계열이 아닌 응답 본문의
    /// `msg_cd` 로만 알려준다. 상태 코드만 보면 재발급 경로를 타지 못하고 그대로 실패로 굳는다.
    ///
    /// 확인 필요: 아래 코드 값은 KIS 문서·현장 보고에서 가장 널리 쓰이는 것이고 실키 검증 전이다.
    static func indicatesExpiredCredential(statusCode: Int, data: Data?) -> Bool {
        if statusCode == 401 { return true }

        guard let code = messageCode(from: data) else { return false }
        return expiredCredentialMessageCodes.contains(code)
    }

    /// `EGW00121` 유효하지 않은 토큰 · `EGW00123` 기간이 만료된 토큰
    private static let expiredCredentialMessageCodes: Set<String> = ["EGW00121", "EGW00123"]

    /// KIS 는 `msg1`, 업비트는 `error.message` 에 실패 사유를 담는다.
    private static func serverMessage(from data: Data?) -> String? {
        guard let json = jsonObject(from: data) else { return nil }

        if let message = json["msg1"] as? String, !message.isEmpty {
            return message
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }

    private static func messageCode(from data: Data?) -> String? {
        guard let code = jsonObject(from: data)?["msg_cd"] as? String, !code.isEmpty else {
            return nil
        }
        return code
    }

    private static func jsonObject(from data: Data?) -> [String: Any]? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
