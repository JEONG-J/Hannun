//
//  KISTokenDTO.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// `POST /oauth2/tokenP` 응답. 이 요청만은 `rt_cd` 봉투를 쓰지 않는다.
struct KISTokenDTO: Decodable, Sendable, Equatable {
    let accessToken: String
    let tokenType: String?

    /// 남은 유효 시간(초). KIS 는 24시간(86400)을 준다.
    let expiresIn: TimeInterval?

    /// `2026-08-02 09:00:00` 형태의 만료 시각 문자열 (한국 표준시).
    let expiresAtText: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case expiresAtText = "access_token_token_expired"
    }
}

extension KISTokenDTO {
    /// `expires_in` 이 없을 때 쓰는 보수적 기본 유효기간.
    private static let defaultLifetime: TimeInterval = 24 * 60 * 60

    func toDomain(issuedAt: Date) -> KISToken {
        KISToken(accessToken: accessToken, expiresAt: expiryDate(issuedAt: issuedAt))
    }

    /// 만료 시각은 `expires_in` → 만료 시각 문자열 → 기본 유효기간 순으로 정한다.
    /// 앞의 두 값 중 하나만 오는 경우가 보고돼 있어 어느 쪽이 없어도 동작해야 한다.
    private func expiryDate(issuedAt: Date) -> Date {
        if let expiresIn, expiresIn > 0 {
            return issuedAt.addingTimeInterval(expiresIn)
        }
        if let expiresAtText, let parsed = Self.parseExpiry(expiresAtText) {
            return parsed
        }
        return issuedAt.addingTimeInterval(Self.defaultLifetime)
    }

    /// 토큰 발급은 하루 한 번 수준이라 포매터를 매번 만들어도 비용이 없다.
    /// 반대로 정적 프로퍼티로 두면 `DateFormatter` 가 Sendable 이 아니라 격리 문제가 생긴다.
    private static func parseExpiry(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }
}
