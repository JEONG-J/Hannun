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
/// 않는다. ① 작성 시각 ② 내용(제목·본문) ③ 연결 종목 세 덩어리로 끊는다.
///
/// 시스템이 그리는 면은 두 군데를 덮는다 — 섹션 배경(`surfacePrimary`)과 헤더 타이포다.
/// Form 기본 헤더는 대문자로 갈아 버리는 caption 이라 `textCase(nil)` 로 되돌린 뒤 토큰
/// 서체를 다시 입힌다. 섹션 모서리 반경은 시스템 insetGrouped 값(시안 §6.8 의 16 보다 작다)을
/// 그대로 둔다 — 그 하나 때문에 리스트를 직접 그리면 폼이 주는 키보드·포커스 처리가 통째로
/// 날아간다.
struct JournalComposeView: View {
    // MARK: - Property

    @State private var viewModel: JournalComposeViewModel
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
        onClose: @escaping () -> Void,
        onSaved: @escaping (JournalRecord) -> Void
    ) {
        self.onClose = onClose
        self.onSaved = onSaved
        _viewModel = State(
            initialValue: JournalComposeViewModel(
                composition: composition,
                saveJournal: saveJournal,
                fetchHoldings: fetchHoldings
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                writtenAtSection
                entrySection
                holdingSection
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
        .task {
            focusedField = .title
            await viewModel.loadHoldingTags()
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

    private var holdingSection: some View {
        Section {
            holdingChips
        } header: {
            sectionHeader(Constants.holdingSectionTitle)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    /// 폼 안의 컨트롤이라 glass 를 쓰지 않는 선택형 `TagPill` 로 그린다 (UI 스펙 §5).
    /// 분류는 넘긴다 — 목록 셀의 태그와 같은 색을 써야 여기서 고른 것이 저기서 무엇이 되는지
    /// 이어진다. 유리가 아닌 같은 색의 불투명 wash 로 칠해지는 건 `TagPill` 이 판단한다.
    @ViewBuilder
    private var holdingChips: some View {
        switch viewModel.holdingTagsState {
        case .idle, .loading:
            ProgressView()
        case let .loaded(holdings) where holdings.isEmpty:
            Text(Constants.noHoldingText)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)
        case let .loaded(holdings):
            ChipGroup {
                ForEach(holdings) { holding in
                    TagPill(
                        holding.name,
                        category: holding.category,
                        isSelected: viewModel.isSelected(holding.id)
                    ) {
                        viewModel.toggleHolding(holding.id)
                    }
                }
            }
        case .failed:
            Text(Constants.holdingLoadFailureText)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)
        }
    }

    /// Form 기본 헤더는 대문자로 갈아 버리는 시스템 caption 이다. `textCase(nil)` 로 되돌린 뒤
    /// 토큰 서체를 다시 입혀 다른 화면의 라벨과 같은 목소리로 만든다.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(nil)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Constants.closeTitle) { viewModel.requestClose() }
                .disabled(viewModel.isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(Constants.saveTitle) {
                focusedField = nil
                Task { await viewModel.save() }
            }
            .hannunButtonStyle(.sheetPrimary)
            .disabled(viewModel.isSaving || !viewModel.canSave)
        }
    }
}

fileprivate enum Constants {
    static let composeTitle = "새 일지"
    static let editTitle = "일지 수정"
    static let closeTitle = "닫기"
    static let saveTitle = "저장"

    static let writtenAtTitle = "작성 시각"

    static let entrySectionTitle = "내용"
    static let titlePlaceholder = "제목"
    static let contentPlaceholder = "무엇을, 왜 샀는지 남겨보세요"
    static let contentLineLimit = 8

    static let holdingSectionTitle = "연결 종목 (선택)"
    static let noHoldingText = "연결할 보유 종목이 아직 없어요."
    static let holdingLoadFailureText = "보유 종목을 불러오지 못했어요. 일지는 그대로 저장할 수 있어요."

    static let failureSymbolName = "exclamationmark.circle"
}
