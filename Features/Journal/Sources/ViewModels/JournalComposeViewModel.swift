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
/// 제목 필수 규칙의 판정자는 여전히 `SaveJournalUseCase` 다. `canSave` 는 그 규칙을 다시
/// 세우는 게 아니라 저장 버튼을 언제 누를 수 있는지만 정하고, UseCase 가 돌려주는 실패는
/// 종류를 가리지 않고 `saveState` 인라인으로 흘린다.
@MainActor
@Observable
final class JournalComposeViewModel {
    // MARK: - Property

    var title = ""
    var content = ""
    var alertPrompt: AlertPrompt?

    /// 이 기록이 **일어난** 시각. 사용자가 고른다 (JR-2).
    ///
    /// 매매일지는 사후에 몰아 쓰는 일이 잦다. 화면에 들어온 시각을 그대로 박으면 어제 판 걸
    /// 오늘 적었을 때 일지의 날짜가 매매일이 아니라 "쓴 날" 이 된다 — 최신순 정렬,
    /// "오늘/어제" 표기, "이번 달 n건" 집계가 전부 이 값을 본다.
    ///
    /// 실제 저장 시각은 `save()` 가 따로 `updatedAt` 에 적는다. 둘은 다른 질문에 답하므로
    /// 한쪽이 다른 쪽을 대신하지 않는다.
    var writtenAt: Date

    private(set) var selectedHoldingIDs: [UUID] = []
    private(set) var holdingTagsState: Loadable<[HoldingRecord]> = .idle
    private(set) var saveState: Loadable<JournalRecord> = .idle
    private(set) var isClosed = false

    private let entryID: UUID
    private let editingEntry: JournalRecord?
    /// 화면에 들어왔을 때의 작성 시각. 날짜를 건드렸는지 판단하는 기준선이다.
    private let initialWrittenAt: Date
    private let saveJournal: any SaveJournalUseCaseProtocol
    private let fetchHoldings: any FetchHoldingsUseCaseProtocol

    var isEditing: Bool { editingEntry != nil }

    var isSaving: Bool { saveState.isLoading }

    /// 저장 버튼을 누를 수 있는지 (UI 스펙 §4.4). 제목이 비면 눌러 봐야 검증 실패로 되돌아오므로
    /// 버튼을 죽여 미리 알린다. 인라인 실패 자리는 그대로 살아 있다 — 저장 실패는 검증 말고도
    /// 나므로(저장소 오류 등) 두 장치는 서로를 대체하지 않는다.
    var canSave: Bool { !trimmedTitle.isEmpty }

    /// 저장이 끝난 일지. View 가 이 값으로 화면을 닫을 시점을 판단한다.
    var savedEntry: JournalRecord? { saveState.value }

    /// 저장에 실패한 이유. 제목 누락 같은 검증 실패도 이 자리에 인라인으로 표시된다.
    var saveFailure: AppError? { saveState.error }

    /// 고를 수 있는 작성 시각의 상한 — 지금. 매매일지는 이미 일어난 일을 적는 기록이라
    /// 앞날의 매매를 미리 적을 일이 없다.
    ///
    /// 판정을 UseCase 가 아니라 Picker 범위에 둔 이유는 이게 "저장해도 되는가" 가 아니라
    /// "고를 수 있는가" 의 문제이기 때문이다. 제목 필수 규칙은 빈 제목이 만들어질 길이 여러
    /// 갈래라 UseCase 가 판정자여야 하지만, 작성 시각은 이 Picker 말고 값이 들어올 곳이 없다.
    /// 애초에 못 고르게 하면 되돌려 보낼 에러 문구 자체가 필요 없다.
    var selectableWrittenAtRange: PartialRangeThrough<Date> { ...Date() }

    /// 닫기 확인이 필요한지. 새 글은 뭐라도 썼는지, 수정은 원본과 달라졌는지를 본다.
    ///
    /// 날짜도 센다 — 날짜만 바꾸고 닫으면 확인 없이 조용히 버려진다.
    var hasUnsavedChanges: Bool {
        guard writtenAt == initialWrittenAt else { return true }

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

        // 수정 모드는 원본 시각을 그대로 싣는다 — 다시 여는 것만으로 매매일이 오늘로 밀리면
        // 안 된다.
        initialWrittenAt = composition.editing?.writtenAt ?? now
        writtenAt = initialWrittenAt
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
            holdingTagsState = .failed(AppError(narrowing: error))
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
            saveState = .failed(AppError(narrowing: error))
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
