//
//  KISCredentials.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// KIS 앱키·앱시크릿.
///
/// 값은 **gitignore 된 xcconfig → Info.plist → 런타임** 경로로만 흘러온다.
/// 저장소에는 `App/Config/*.xcconfig.example` 템플릿만 있고 실제 키는 어디에도 커밋되지 않는다.
struct KISCredentials: Sendable, Equatable {
    let appKey: String
    let appSecret: String
}

extension KISCredentials {
    static let appKeyInfoPlistKey = "KISAppKey"
    static let appSecretInfoPlistKey = "KISAppSecret"

    /// Info.plist 에서 읽는다.
    ///
    /// 키가 비어 있으면(템플릿 그대로) 에러가 아니라 **미설정**으로 다룬다. 키가 없어도 코인
    /// 시세와 수동 입력 폴백은 그대로 동작해야 하므로, 앱 실행 자체를 막을 이유가 없다.
    static func fromInfoPlist(_ bundle: Bundle = .main) -> KISCredentials? {
        guard
            let appKey = bundle.object(forInfoDictionaryKey: appKeyInfoPlistKey) as? String,
            let appSecret = bundle.object(forInfoDictionaryKey: appSecretInfoPlistKey) as? String
        else { return nil }

        let trimmedKey = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = appSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedSecret.isEmpty else { return nil }

        return KISCredentials(appKey: trimmedKey, appSecret: trimmedSecret)
    }
}
