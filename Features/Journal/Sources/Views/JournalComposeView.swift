//
//  JournalComposeView.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 일지 작성·수정 화면 (JR-2, JR-3).
///
/// `Form` 으로 짓는다 — 세로로 그냥 쌓으면 어디까지가 한 덩어리의 입력인지가 배치로 드러나지
/// 않는다. ① 작성 시각 ② 연결 종목 ③ 내용(제목·본문) 세 덩어리로 끊는다.
///
/// **고르는 일이 먼저고 쓰는 일이 나중이다.** 앞의 둘은 정해진 선택지에서 집어 오는 입력이라
/// 끝이 있지만 제목·본문은 길이가 정해지지 않은 입력이다. 끝나는 입력을 위에 두면 아래로
/// 내려갈수록 화면이 열리고, 키보드가 올라와도 그 아래에서 밀려날 것이 없다.
///
/// 시스템이 그리는 면은 두 군데를 덮는다 — 섹션 배경(`surfacePrimary`)과 헤더 타이포다.
/// Form 기본 헤더는 대문자로 갈아 버리는 caption 이라 `textCase(nil)` 로 되돌린 뒤 토큰
/// 서체를 다시 입힌다. 섹션 모서리 반경은 시스템 insetGrouped 값(시안 §6.8 의 16 보다 작다)을
/// 그대로 둔다 — 그 하나 때문에 리스트를 직접 그리면 폼이 주는 키보드·포커스 처리가 통째로
/// 날아간다.
struct JournalComposeView: View {
    // MARK: - Property

    @State private var viewModel: JournalComposeViewModel
    @State private var isPickingHoldings = false
    @State private var isDraftingContent = false
    @FocusState private var focusedField: Field?

    private let onClose: () -> Void
    private let onSaved: (JournalRecord) -> Void

    private enum Field {
        case title
        case content
    }

    // MARK: - Body

    init(
        composition: JournalComposition,
        saveJournal: any SaveJournalUseCaseProtocol,
        fetchHoldings: any FetchHoldingsUseCaseProtocol,
        draftContent: any DraftJournalContentUseCaseProtocol,
        onClose: @escaping () -> Void,
        onSaved: @escaping (JournalRecord) -> Void
    ) {
        self.onClose = onClose
        self.onSaved = onSaved
        _viewModel = State(
            initialValue: JournalComposeViewModel(
                composition: composition,
                saveJournal: saveJournal,
                fetchHoldings: fetchHoldings,
                draftContent: draftContent
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                writtenAtSection
                holdingSection
                entrySection
            }
            // Form 기본 배경은 시스템 grouped 색이라 토큰 배경 위에 회색 판이 한 겹 더 깔린다.
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimary)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(viewModel.isEditing ? Constants.editTitle : Constants.composeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .alertPrompt(item: $viewModel.alertPrompt)
        .sheet(isPresented: $isPickingHoldings) {
            JournalHoldingPickerView(
                viewModel: viewModel,
                holdings: viewModel.holdingTagsState.value ?? []
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isDraftingContent) {
            JournalContentDraftView(viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
        // 제목에 자동 포커스를 주지 않는다 — 제목이 폼 맨 아래로 내려가서, 키보드를 띄우면
        // 화면이 곧장 바닥으로 스크롤돼 위의 두 줄이 처음부터 가려진다.
        .task {
            await viewModel.loadHoldingTags()
        }
        // 종목 조회와 갈라 둔다. 이쪽은 기기 안에서 끝나는 확인이라, 시세 응답을 기다리는
        // 동안 초안 입구만 없는 화면이 되지 않는다.
        .task {
            await viewModel.loadWriterAvailability()
        }
        .onChange(of: viewModel.isClosed) { _, isClosed in
            guard isClosed else { return }
            onClose()
        }
        .onChange(of: viewModel.savedEntry) { _, savedEntry in
            guard let savedEntry else { return }
            onSaved(savedEntry)
        }
    }

    /// 작성 시각은 사용자가 고른다 (JR-2). 기본값은 지금이고 미래는 고를 수 없다 —
    /// 범위 판정의 근거는 `JournalComposeViewModel.selectableWrittenAtRange` 에 적어 뒀다.
    ///
    /// 헤더를 달지 않는다. `DatePicker` 라벨이 이미 "작성 시각" 이라 헤더를 얹으면 같은 말이
    /// 두 줄로 겹친다.
    private var writtenAtSection: some View {
        Section {
            DatePicker(
                Constants.writtenAtTitle,
                selection: $viewModel.writtenAt,
                in: viewModel.selectableWrittenAtRange,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .hannunFont(.body)
            .foregroundStyle(Color.textPrimary)
            .tint(Color.brand)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    /// 제목과 본문은 같은 덩어리다 — 둘 다 "무엇을 왜" 를 적는 자리고, 제목만 필수다.
    private var entrySection: some View {
        Section {
            titleField

            if let failure = viewModel.saveFailure {
                failureLabel(failure)
            }

            contentField
        } header: {
            sectionHeader(Constants.entrySectionTitle)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    private var titleField: some View {
        TextField(Constants.titlePlaceholder, text: $viewModel.title)
            .hannunFont(.rowTitle)
            .foregroundStyle(Color.textPrimary)
            .submitLabel(.next)
            .focused($focusedField, equals: .title)
            .onSubmit { focusedField = .content }
    }

    /// 저장 실패는 화면을 벗어나지 않는 상태라 인라인으로만 알린다 — 제목 누락 검증도 같은
    /// 자리다. 폼으로 바뀐 뒤에도 제목 바로 아래에 둬서 무엇이 문제인지 눈이 옮겨 가지 않게 한다.
    private func failureLabel(_ failure: AppError) -> some View {
        Label(failure.userMessage, systemImage: Constants.failureSymbolName)
            .hannunFont(.caption)
            .foregroundStyle(Color.warning)
    }

    private var contentField: some View {
        TextField(
            Constants.contentPlaceholder,
            text: $viewModel.content,
            axis: .vertical
        )
        .hannunFont(.body)
        .foregroundStyle(Color.textPrimary)
        .lineLimit(Constants.contentLineLimit, reservesSpace: true)
        .focused($focusedField, equals: .content)
    }

    /// 연결 종목은 줄 하나로 접고, 고르는 일은 화면 하나(`JournalHoldingPickerView`)에 넘긴다.
    ///
    /// 헤더를 달지 않는 건 작성 시각 섹션과 같은 이유다 — 행 라벨이 이미 "연결 종목" 이다.
    private var holdingSection: some View {
        Section {
            holdingRow
        }
        .listRowBackground(Color.surfacePrimary)
    }

    @ViewBuilder
    private var holdingRow: some View {
        switch viewModel.holdingTagsState {
        case .idle, .loading:
            ProgressView()
        case let .loaded(holdings) where holdings.isEmpty:
            Text(Constants.noHoldingText)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)
        case .loaded:
            holdingDisclosure
        case .failed:
            Text(Constants.holdingLoadFailureText)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var holdingDisclosure: some View {
        Button {
            focusedField = nil
            isPickingHoldings = true
        } label: {
            HStack(spacing: .spacingS) {
                Text(Constants.holdingRowTitle)
                    .hannunFont(.body)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text(selectionSummary)
                    .hannunFont(.subtext)
                    .foregroundStyle(Color.textSecondary)

                Image(systemName: Constants.disclosureSymbolName)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// 몇 개 골랐는지만 말한다. 고른 종목을 칩으로 다시 늘어놓으면 방금 접어 넣은 가로 줄이
    /// 그대로 돌아온다 — 무엇을 골랐는지는 선택 화면이 표식으로 보여 준다.
    private var selectionSummary: String {
        let count = viewModel.selectedHoldingIDs.count
        guard count > 0 else { return Constants.noSelectionText }
        return "\(count)\(Constants.selectionCountSuffix)"
    }

    /// Form 기본 헤더는 대문자로 갈아 버리는 시스템 caption 이다. `textCase(nil)` 로 되돌린 뒤
    /// 토큰 서체를 다시 입혀 다른 화면의 라벨과 같은 목소리로 만든다.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(nil)
    }

    /// 셋 다 글자가 아니라 심볼로 세운다 — 인라인 제목 양옆에서 글자가 마주 서면 제목이
    /// 여러 덩어리 중 하나로 묻히고, 좁은 폭에서 먼저 잘리는 것도 이 자리다. 문구는 접근성
    /// 라벨로 남아 VoiceOver 에는 그대로 읽힌다 (일지 상세 툴바와 같은 형).
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Constants.closeTitle, systemImage: Constants.closeSymbolName) {
                viewModel.requestClose()
            }
            .labelStyle(.iconOnly)
            .disabled(viewModel.isSaving)
        }

        if viewModel.canOfferContentDraft {
            ToolbarItem(placement: .topBarTrailing) {
                draftAssistButton
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(Constants.saveTitle, systemImage: Constants.saveSymbolName) {
                focusedField = nil
                Task { await viewModel.save() }
            }
            .labelStyle(.iconOnly)
            .hannunButtonStyle(.sheetPrimary)
            .disabled(viewModel.isSaving || !viewModel.canSave)
        }
    }

    /// Apple Intelligence 입구. 저장 왼쪽에 세워 두 동작이 같은 손 끝에서 갈리게 한다.
    ///
    /// 이 자리에서만 토큰 색을 쓰지 않는다 — 무지개는 장식이 아니라 **모델이 쓴 글로 가는
    /// 문**이라는 표식이라, 다른 툴바 아이콘처럼 단색으로 칠하면 그 신호가 사라진다
    /// (`ShapeStyle.intelligence`).
    ///
    /// 색은 라벨이 아니라 `Image` 에 직접 입힌다. 툴바 버튼은 자기 tint 로 라벨을 칠하므로
    /// `Button` 바깥에 얹으면 유리 버튼의 단색에 덮인다.
    ///
    /// 쓸 수 없는 기기에서는 이 항목이 아예 없다 — 판단은 `canOfferContentDraft` 가 한다.
    private var draftAssistButton: some View {
        Button {
            focusedField = nil
            isDraftingContent = true
        } label: {
            Image(systemName: Constants.draftAssistSymbolName)
                .foregroundStyle(.intelligence)
        }
        .accessibilityLabel(Constants.draftAssistTitle)
        .disabled(viewModel.isSaving)
    }
}

fileprivate enum Constants {
    static let composeTitle = "새 일지"
    static let editTitle = "일지 수정"
    static let closeTitle = "닫기"
    static let closeSymbolName = "xmark"
    static let saveTitle = "저장"
    static let saveSymbolName = "checkmark"

    static let writtenAtTitle = "작성 시각"

    static let entrySectionTitle = "내용"
    static let titlePlaceholder = "제목"
    static let contentPlaceholder = "무엇을, 왜 샀는지 남겨보세요"
    static let contentLineLimit = 8
    static let draftAssistTitle = "본문 초안 만들기"
    static let draftAssistSymbolName = "apple.intelligence"

    static let holdingRowTitle = "연결 종목"
    static let noSelectionText = "선택 안 함"
    static let selectionCountSuffix = "개 선택됨"
    static let disclosureSymbolName = "chevron.right"
    static let noHoldingText = "연결할 보유 종목이 아직 없어요."
    static let holdingLoadFailureText = "보유 종목을 불러오지 못했어요. 일지는 그대로 저장할 수 있어요."

    static let failureSymbolName = "exclamationmark.circle"
}
