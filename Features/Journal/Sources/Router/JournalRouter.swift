//
//  JournalRouter.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDomain
import Observation

/// 매매일지 탭 안에서 push 로 열리는 화면.
enum JournalRoute: Hashable {
    case detail(JournalRecord)

    /// `JournalRecord` 는 Equatable 이지만 Hashable 이 아니다. 경로를 구분하는 데는
    /// 식별자만으로 충분하므로 여기서 좁혀 해시한다.
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .detail(record):
            hasher.combine(record.id)
        }
    }
}

/// 작성 화면에 넘길 대상. 새 글이면 `editing` 이 비어 있다 (JR-2 / JR-3).
struct JournalComposition: Identifiable {
    // MARK: - Property

    let id: UUID
    let editing: JournalRecord?

    // MARK: - Function

    static var draft: JournalComposition {
        JournalComposition(id: UUID(), editing: nil)
    }

    static func revision(of record: JournalRecord) -> JournalComposition {
        JournalComposition(id: record.id, editing: record)
    }
}

/// 매매일지 탭 내부 화면 전환. 탭 경계를 넘는 이동은 앱 타깃의 AppRouter 가 맡는다.
@MainActor
@Observable
final class JournalRouter {
    // MARK: - Property

    var path: [JournalRoute] = []
    var composition: JournalComposition?

    // MARK: - Function

    func showDetail(of record: JournalRecord) {
        path.append(.detail(record))
    }

    func composeNewEntry() {
        composition = .draft
    }

    func edit(_ record: JournalRecord) {
        composition = .revision(of: record)
    }

    func dismissComposition() {
        composition = nil
    }

    /// 상세로 열어 둔 일지가 수정되면 경로에 남은 값도 새 내용으로 바꾼다.
    /// 그러지 않으면 저장 직후 상세 화면이 수정 전 내용을 계속 보여준다.
    func refreshDetail(with record: JournalRecord) {
        guard case let .detail(shown)? = path.last, shown.id == record.id else { return }
        path[path.index(before: path.endIndex)] = .detail(record)
    }

    func closeDetail() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
