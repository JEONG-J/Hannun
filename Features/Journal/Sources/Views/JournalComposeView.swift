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
struct JournalComposeView: View {
    // MARK: - Property

    @State private var viewModel: JournalComposeViewModel
    @FocusState private var focusedField: Field?

    private let onClose: () -> Void
    private let onSaved: (JournalRecord) -> Void
    private let dateStyle = JournalDateStyle()

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
            ScrollView {
                VStack(alignment: .leading, spacing: .spacingL) {
                    timestampLabel
                    titleField
                    contentField
                    holdingSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, .spacingL)
                .padding(.vertical, .spacingM)
            }
            .background(Color.backgroundPrimary)
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

    /// 작성 시각은 저장 시점에 자동으로 기록된다 — 사용자가 고르는 입력이 아니다 (JR-2).
    private var timestampLabel: some View {
        Text(dateStyle.timestampText(for: viewModel.writtenAt))
            .hannunFont(.caption, tabularFigures: true)
            .foregroundStyle(Color.textSecondary)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            TextField(Constants.titlePlaceholder, text: $viewModel.title)
                .hannunFont(.rowTitle)
                .foregroundStyle(Color.textPrimary)
                .submitLabel(.next)
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .content }

            if let failure = viewModel.saveFailure {
                failureLabel(failure)
            }

            Divider()
                .overlay(Color.separator)
        }
    }

    /// 저장 실패는 화면을 벗어나지 않는 상태라 인라인으로만 알린다 — 제목 누락 검증도 같은 자리다.
    private func failureLabel(_ failure: AppError) -> some View {
        Label(failure.userMessage, systemImage: Constants.failureSymbolName)
            .hannunFont(.caption)
            // 팔레트에 경고 전용 토큰이 없다. `gain` 이 앱의 유일한 빨강이라 이를 빌려 쓴다.
            .foregroundStyle(Color.gain)
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
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(Constants.holdingSectionTitle)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            holdingChips
        }
    }

    /// 폼 안의 컨트롤이라 glass 를 쓰지 않는 선택형 `TagPill` 로 그린다.
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
                    TagPill(holding.name, isSelected: viewModel.isSelected(holding.id)) {
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
            .disabled(viewModel.isSaving)
        }
    }
}

fileprivate enum Constants {
    static let composeTitle = "새 일지"
    static let editTitle = "일지 수정"
    static let closeTitle = "닫기"
    static let saveTitle = "저장"

    static let titlePlaceholder = "제목"
    static let contentPlaceholder = "무엇을, 왜 샀는지 남겨보세요"
    static let contentLineLimit = 8

    static let holdingSectionTitle = "연결 종목 (선택)"
    static let noHoldingText = "연결할 보유 종목이 아직 없어요."
    static let holdingLoadFailureText = "보유 종목을 불러오지 못했어요. 일지는 그대로 저장할 수 있어요."

    static let failureSymbolName = "exclamationmark.circle"
}
