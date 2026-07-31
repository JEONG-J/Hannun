//
//  AppError+Persistence.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

extension AppError {
    /// SwiftData 가 던진 에러를 앱 에러로 바꾼다. 이미 `AppError` 면 그대로 통과시킨다.
    init(persistence error: any Error) {
        if let appError = error as? AppError {
            self = appError
        } else {
            self = .persistence(error.localizedDescription)
        }
    }
}

/// 저장소 작업을 감싸 원시 에러가 Domain 으로 새어 나가지 않게 한다.
func persisting<Value>(_ work: () throws -> Value) throws -> Value {
    do {
        return try work()
    } catch {
        throw AppError(persistence: error)
    }
}
