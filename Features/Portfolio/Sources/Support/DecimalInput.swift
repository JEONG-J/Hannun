//
//  DecimalInput.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 숫자 입력 필드의 문자열 ↔ `Decimal` 변환.
///
/// `TextField(value:format:)` 대신 문자열을 들고 있는 이유는, 편집 도중의 빈 문자열과
/// "0" 을 구분해야 검증 문구를 제때 띄울 수 있어서다.
enum DecimalInput {

    // MARK: - Function

    /// 천 단위 구분자와 공백은 무시한다. 숫자로 읽히지 않으면 nil.
    static func value(from text: String) -> Decimal? {
        let separator = Locale.current.groupingSeparator ?? Constants.fallbackGroupingSeparator
        let normalized = text
            .replacingOccurrences(of: separator, with: "")
            .trimmingCharacters(in: .whitespaces)

        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: .current)
    }

    static func text(from value: Decimal?) -> String {
        guard let value else { return "" }
        return value.formatted(
            .number
                .precision(.fractionLength(0...Constants.maximumFractionDigits))
                .grouping(.never)
        )
    }
}

fileprivate enum Constants {
    static let fallbackGroupingSeparator = ","
    static let maximumFractionDigits = 8
}
