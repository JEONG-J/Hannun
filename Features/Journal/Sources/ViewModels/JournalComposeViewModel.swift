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

    /// 초안 화면에 남기는 메모. 일지에는 저장되지 않는 재료라서 `content` 와 자리가 다르다.
    var draftMemo = ""

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

    /// 초안 생성기의 가용 상태. **못 쓴다고 보고 시작한다** — 확인이 끝나기 전에 버튼부터
    /// 내놓으면 눌러 봐야 "쓸 수 없다" 로 되돌아오는 자리가 화면에 잠깐 생긴다.
    private(set) var writerAvailability: JournalContentAvailability = .unsupportedDevice
    private(set) var contentDraftState: Loadable<String> = .idle

    private let entryID: UUID
    private let editingEntry: JournalRecord?
    /// 화면에 들어왔을 때의 작성 시각. 날짜를 건드렸는지 판단하는 기준선이다.
    private let initialWrittenAt: Date
    private let saveJournal: any SaveJournalUseCaseProtocol
    private let fetchHoldings: any FetchHoldingsUseCaseProtocol
    private let draftContent: any DraftJournalContentUseCaseProtocol

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

    /// 초안 기능을 화면에 내놓아도 되는지. 쓸 수 없는 기기에서는 입구 자체를 만들지 않는다 —
    /// 눌러야 못 쓴다고 알려 주는 버튼은 알림을 주는 게 아니라 길을 한 번 더 막는 것이다.
    var canOfferContentDraft: Bool { writerAvailability.isReady }

    var isDraftingContent: Bool { contentDraftState.isLoading }

    /// 아직 본문이 되지 않은 초안. 사용자가 읽고 받아들여야 `content` 로 옮겨진다.
    var contentDraft: String? { contentDraftState.value }

    var contentDraftFailure: AppError? { contentDraftState.error }

    /// 초안을 받으면 지금 본문이 통째로 바뀌는지. 버튼 문구를 갈아 그 사실을 미리 말한다.
    var draftReplacesContent: Bool { !trimmedContent.isEmpty }

    /// 초안을 만들 재료가 있는지. 판정자는 `DraftJournalContentUseCase` 고, 여기서는 눌러도
    /// 되는지만 정한다 — 저장 버튼과 같은 형이다.
    var canRequestContentDraft: Bool {
        !trimmedTitle.isEmpty || !trimmedDraftMemo.isEmpty || !selectedHoldingIDs.isEmpty
    }

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

    private var trimmedDraftMemo: String {
        draftMemo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 초안에 넘길 종목 이름. 고른 순서를 그대로 따라가 재료의 순서가 화면과 어긋나지 않게 한다.
    private var selectedHoldingNames: [String] {
        let holdings = holdingTagsState.value ?? []
        return selectedHoldingIDs.compactMap { holdingID in
            holdings.first { $0.id == holdingID }?.name
        }
    }

    // MARK: - Function

    init(
        composition: JournalComposition,
        saveJournal: any SaveJournalUseCaseProtocol,
        fetchHoldings: any FetchHoldingsUseCaseProtocol,
        draftContent: any DraftJournalContentUseCaseProtocol,
        now: Date = Date()
    ) {
        entryID = composition.id
        editingEntry = composition.editing
        self.saveJournal = saveJournal
        self.fetchHoldings = fetchHoldings
        self.draftContent = draftContent

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

    /// 종목 목록과 따로 부른다. 이쪽은 기기 안에서 끝나는 확인이라 시세 조회가 늦어도
    /// 초안 입구는 제때 나타나야 한다.
    func loadWriterAvailability() async {
        writerAvailability = await draftContent.availability()
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

    /// 고른 종목을 한 번에 비운다. 하나씩 눌러 끄는 것과 결과는 같지만, 여러 개 골라 둔 뒤
    /// 처음부터 다시 고르는 경로가 고른 개수만큼 길어지는 걸 막는다.
    func clearHoldings() {
        selectedHoldingIDs.removeAll()
    }

    /// 화면이 이미 들고 있는 값에 메모를 얹어 초안을 청한다. 재료를 따로 묻지 않는 이유는
    /// 제목·시각·종목이 이미 폼에 적혀 있어서다 — 같은 걸 두 번 적게 하면 초안이 더 번거롭다.
    func requestContentDraft() async {
        contentDraftState = .loading

        let request = JournalContentRequest(
            title: trimmedTitle,
            writtenAt: writtenAt,
            holdingNames: selectedHoldingNames,
            memo: trimmedDraftMemo
        )

        do {
            contentDraftState = .loaded(try await draftContent.execute(request))
        } catch {
            contentDraftState = .failed(AppError(narrowing: error))
        }
    }

    /// 초안은 눌러야 본문이 된다. 만들자마자 덮으면 쓰고 있던 문장이 확인 한 번 없이 사라지고,
    /// 되돌릴 자리도 없다 — 아직 저장 전이라 폼에는 취소가 없다.
    func applyContentDraft() {
        guard let draft = contentDraftState.value else { return }

        content = draft
        contentDraftState = .idle
        draftMemo = ""
    }

    /// 초안만 버리고 메모는 남긴다. 마음에 안 들어 다시 만드는 경로가 대부분이라 메모까지
    /// 지우면 방금 적은 걸 그대로 다시 적어야 한다.
    func discardContentDraft() {
        contentDraftState = .idle
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
