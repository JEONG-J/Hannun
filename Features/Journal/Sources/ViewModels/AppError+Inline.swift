//
//  AppError+Inline.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

extension AppError {
    /// 임의의 에러를 인라인 `Loadable` 에 실을 수 있는 형태로 좁힌다.
    /// `ErrorHandler` 가 전역 Alert 경로에서 하는 변환과 같은 규칙이다.
    static func inline(_ error: any Error) -> AppError {
        error as? AppError ?? .unknown(String(describing: error))
    }
}
