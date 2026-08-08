//
//  KISCredentials.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// KIS 앱키·앱시크릿.
///
/// 값은 **사용자가 설정 화면에서 직접 입력**해 Keychain 으로만 흘러온다. 앱 바이너리에는 어떤
/// 키도 넣지 않는다 — 앱키는 증권 계좌를 조작할 권한이라 배포본에 박으면 뜯는 즉시 새어 나가고,
/// KIS 유량 제한도 계좌 단위라 모든 사용자가 한 계좌를 나눠 쓰게 된다.
struct KISCredentials: Codable, Sendable, Equatable {
    let appKey: String
    let appSecret: String
}

extension KISCredentials {
    /// 사용자가 입력한 두 값에서 만든다.
    ///
    /// 앞뒤 공백을 털어내는 이유는 이 칸의 주된 입력 수단이 **붙여넣기**이기 때문이다 — 36자
    /// 랜덤 문자열을 손으로 치는 사람은 없고, 개발자센터에서 복사하면 줄바꿈이 딸려 온다.
    /// 한쪽이라도 비면 자격증명이 아니라 **미설정**으로 다룬다.
    static func sanitized(appKey: String, appSecret: String) -> KISCredentials? {
        let trimmedKey = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = appSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedSecret.isEmpty else { return nil }

        return KISCredentials(appKey: trimmedKey, appSecret: trimmedSecret)
    }
}
