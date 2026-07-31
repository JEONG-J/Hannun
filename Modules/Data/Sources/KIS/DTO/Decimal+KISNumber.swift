//
//  Decimal+KISNumber.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

extension Decimal {
    /// KIS 는 모든 수치를 문자열로 준다.
    ///
    /// 조회 결과가 없는 종목은 값 대신 빈 문자열이 오므로 nil 로 떨궈 배치 조회에서 빠지게 한다.
    /// 로케일을 POSIX 로 고정하는 이유는 기기 설정에 따라 소수점 구분자가 `,` 로 해석돼
    /// 가격이 통째로 어긋나는 것을 막기 위해서다.
    init?(kisNumber raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        self.init(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }
}
