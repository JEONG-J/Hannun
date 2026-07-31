//
//  JournalDetailViewModel.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 일지 상세 화면 상태. 삭제는 확인 다이얼로그를 거친다 (JR-3).
@MainActor
@Observable
final class JournalDetailViewModel {
    // MARK: - Property

    private(set) var record: JournalRecord
    private(set) var deleteState: Loadable<UUID> = .idle

    var alertPrompt: AlertPrompt?

    private let deleteJournal: any DeleteJournalUseCaseProtocol
    private let errorHandler: ErrorHandler

    var isDeleting: Bool { deleteState.isLoading }

    /// 삭제가 끝난 일지의 식별자. 화면을 닫을 시점을 View 가 이 값으로 판단한다.
    var deletedEntryID: UUID? { deleteState.value }

    // MARK: - Function

    init(
        record: JournalRecord,
        deleteJournal: any DeleteJournalUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.record = record
        self.deleteJournal = deleteJournal
        self.errorHandler = errorHandler
    }

    func apply(_ record: JournalRecord) {
        self.record = record
    }

    /// 되돌릴 수 없는 작업이므로 확인부터 받는다.
    func requestDelete() {
        alertPrompt = AlertPrompt(
            title: Constants.deleteTitle,
            message: Constants.deleteMessage,
            confirmTitle: Constants.deleteConfirmTitle,
            isDestructive: true,
            confirmAction: { [weak self] in
                Task { await self?.delete() }
            }
        )
    }

    /// 삭제 실패는 화면 안에 머무는 상태가 아니라 흐름이 끊긴 것이므로 전역 Alert 으로 보낸다.
    func delete() async {
        deleteState = .loading
        do {
            try await deleteJournal.execute(id: record.id)
            deleteState = .loaded(record.id)
        } catch {
            deleteState = .idle
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: Constants.errorFeatureName,
                    action: Constants.errorActionName,
                    retryAction: { [weak self] in await self?.delete() }
                )
            )
        }
    }
}

fileprivate enum Constants {
    static let deleteTitle = "일지를 삭제할까요?"
    static let deleteMessage = "삭제한 일지는 되돌릴 수 없어요."
    static let deleteConfirmTitle = "삭제"
    static let errorFeatureName = "Journal"
    static let errorActionName = "delete"
}
