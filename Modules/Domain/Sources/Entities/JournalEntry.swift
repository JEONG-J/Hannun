//
//  JournalEntry.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import SwiftData

/// 매매일지 1건. 종목 연결은 0개 이상이고 선택 사항이다.
@Model
public final class JournalEntry {
    // MARK: - Property

    public var id: UUID = UUID()
    public var writtenAt: Date = Date()
    public var title: String = ""
    public var content: String = ""
    public var updatedAt: Date = Date()

    /// 종목 태그. CloudKit 은 양방향·optional 관계만 허용하므로 반대편을 `Holding` 이 들고 있다.
    @Relationship(inverse: \Holding.journalEntries)
    public var holdings: [Holding]?

    public var record: JournalRecord {
        JournalRecord(
            id: id,
            writtenAt: writtenAt,
            title: title,
            content: content,
            holdingIDs: (holdings ?? []).map(\.id),
            updatedAt: updatedAt
        )
    }

    // MARK: - Function

    public init(record: JournalRecord) {
        id = record.id
        writtenAt = record.writtenAt
        title = record.title
        content = record.content
        updatedAt = record.updatedAt
    }

    /// 종목 태그는 `Holding` 인스턴스를 알아야 해서 Repository 가 따로 채운다.
    public func apply(_ record: JournalRecord) {
        writtenAt = record.writtenAt
        title = record.title
        content = record.content
        updatedAt = record.updatedAt
    }
}

/// `JournalEntry` 의 값 타입 표현. 연결 종목은 식별자로만 들고 다닌다.
public struct JournalRecord: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let id: UUID
    public var writtenAt: Date
    public var title: String
    public var content: String
    public var holdingIDs: [UUID]
    public var updatedAt: Date

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        writtenAt: Date = Date(),
        title: String,
        content: String = "",
        holdingIDs: [UUID] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.writtenAt = writtenAt
        self.title = title
        self.content = content
        self.holdingIDs = holdingIDs
        self.updatedAt = updatedAt
    }
}
