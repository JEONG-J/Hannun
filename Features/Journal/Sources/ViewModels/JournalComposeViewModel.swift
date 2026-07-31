//
//  JournalComposeViewModel.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 일지 작성·수정 화면 상태 (JR-2, JR-3).
///
/// 제목 필수 규칙은 여기서 판정하지 않는다 — `SaveJournalUseCase` 가 유일한 판정자이고,
/// 이 타입은 그 결과를 `saveState` 인라인 실패로 옮기기만 한다.
@MainActor
@Observable
final class JournalComposeViewModel {
    // MARK: - Property

    var title = ""
    var content = ""
    var alertPrompt: AlertPrompt?

    private(set) var selectedHoldingIDs: [UUID] = []
    private(set) var holdingTagsState: Loadable<[HoldingRecord]> = .idle
    private(set) var saveState: Loadable<JournalRecord> = .idle
    private(set) var isClosed = false

    /// 자동으로 기록되는 작성 시각. 사용자 입력 UI 가 없다 (JR-2).
    let writtenAt: Date

    private let entryID: UUID
    private let editingEntry: JournalRecord?
    private let saveJournal: any SaveJournalUseCaseProtocol
    private let fetchHoldings: any FetchHoldingsUseCaseProtocol

    var isEditing: Bool { editingEntry != nil }

    var isSaving: Bool { saveState.isLoading }

    /// 저장이 끝난 일지. View 가 이 값으로 화면을 닫을 시점을 판단한다.
    var savedEntry: JournalRecord? { saveState.value }

    /// 저장에 실패한 이유. 제목 누락 같은 검증 실패도 이 자리에 인라인으로 표시된다.
    var saveFailure: AppError? { saveState.error }

    /// 닫기 확인이 필요한지. 새 글은 뭐라도 썼는지, 수정은 원본과 달라졌는지를 본다.
    var hasUnsavedChanges: Bool {
        guard let editingEntry else {
            return !trimmedTitle.isEmpty || !trimmedContent.isEmpty
                || !selectedHoldingIDs.isEmpty
        }

        return trimmedTitle != editingEntry.title
            || trimmedContent != editingEntry.content
            || Set(selectedHoldingIDs) != Set(editingEntry.holdingIDs)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Function

    init(
        composition: JournalComposition,
        saveJournal: any SaveJournalUseCaseProtocol,
        fetchHoldings: any FetchHoldingsUseCaseProtocol,
        now: Date = Date()
    ) {
        entryID = composition.id
        editingEntry = composition.editing
        self.saveJournal = saveJournal
        self.fetchHoldings = fetchHoldings

        writtenAt = composition.editing?.writtenAt ?? now
        title = composition.editing?.title ?? ""
        content = composition.editing?.content ?? ""
        selectedHoldingIDs = composition.editing?.holdingIDs ?? []
    }

    func loadHoldingTags() async {
        holdingTagsState = .loading
        do {
            let valuations = try await fetchHoldings.execute(
                category: nil,
                baseCurrency: .krw,
                exchangeRate: Constants.tagOnlyExchangeRate
            )
            holdingTagsState = .loaded(valuations.map(\.holding))
        } catch {
            holdingTagsState = .failed(.inline(error))
        }
    }

    func isSelected(_ holdingID: UUID) -> Bool {
        selectedHoldingIDs.contains(holdingID)
    }

    /// 종목 태그는 0개 이상이고 선택 사항이다 (JR-2).
    /// 선택 순서를 그대로 보관해 저장 후에도 태그 나열 순서가 흔들리지 않게 한다.
    func toggleHolding(_ holdingID: UUID) {
        if let index = selectedHoldingIDs.firstIndex(of: holdingID) {
            selectedHoldingIDs.remove(at: index)
        } else {
            selectedHoldingIDs.append(holdingID)
        }
    }

    func save() async {
        saveState = .loading

        let record = JournalRecord(
            id: entryID,
            writtenAt: writtenAt,
            title: trimmedTitle,
            content: trimmedContent,
            holdingIDs: selectedHoldingIDs,
            updatedAt: Date()
        )

        do {
            try await saveJournal.execute(record)
            saveState = .loaded(record)
        } catch {
            saveState = .failed(.inline(error))
        }
    }

    /// 쓰던 내용이 있으면 확인부터 받는다.
    func requestClose() {
        guard hasUnsavedChanges else {
            isClosed = true
            return
        }

        alertPrompt = AlertPrompt(
            title: Constants.discardTitle,
            message: Constants.discardMessage,
            confirmTitle: Constants.discardConfirmTitle,
            isDestructive: true,
            confirmAction: { [weak self] in
                self?.isClosed = true
            }
        )
    }
}

fileprivate enum Constants {
    static let discardTitle = "작성 중인 내용을 버릴까요?"
    static let discardMessage = "저장하지 않은 내용은 사라져요."
    static let discardConfirmTitle = "버리기"
    /// 태그 칩에는 종목명만 쓰고 평가금액을 읽지 않아 환산 결과가 화면에 나타나지 않는다.
    static let tagOnlyExchangeRate = ExchangeRate(krwPerUSD: 1)
}
