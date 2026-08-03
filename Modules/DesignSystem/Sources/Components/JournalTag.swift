//
//  JournalTag.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore

/// 일지에 달린 종목 태그 하나 — 이름과 그 종목의 분류.
///
/// 이름만 넘기지 않는 이유는 캡슐 색이 분류색이기 때문이다. 문자열만 받으면 셀이 색을 되찾을
/// 길이 없어 태그가 전부 같은 회색으로 돌아간다. 그렇다고 `HoldingRecord` 를 받을 수는 없다 —
/// 디자인 시스템은 도메인 엔티티를 보지 않는다.
public struct JournalTag: Identifiable, Hashable, Sendable {

    // MARK: - Property

    /// 종목 식별자. 같은 이름이 둘 있어도 `ForEach` 가 흔들리지 않게 종목의 id 를 그대로 쓴다.
    public let id: UUID
    public let name: String
    public let category: AssetCategory

    // MARK: - Function

    public init(id: UUID, name: String, category: AssetCategory) {
        self.id = id
        self.name = name
        self.category = category
    }
}
