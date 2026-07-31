//
//  KISToken.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 발급받은 KIS 접근토큰. Keychain 에 직렬화해 보관한다.
struct KISToken: Codable, Sendable, Equatable {
    let accessToken: String
    let expiresAt: Date

    /// 만료까지 `margin` 보다 여유가 있어야 유효로 본다.
    /// 만료 직전 토큰을 그대로 쓰면 요청이 날아가는 사이에 만료돼 401 왕복이 한 번 더 생긴다.
    func isValid(at moment: Date, margin: TimeInterval) -> Bool {
        moment.addingTimeInterval(margin) < expiresAt
    }
}
