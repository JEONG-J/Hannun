//
//  JournalDetailView.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 일지 상세. 수정·삭제 진입점을 갖는다 (JR-3).
struct JournalDetailView: View {
    // MARK: - Property

    @State private var viewModel: JournalDetailViewModel

    private let record: JournalRecord
    private let tags: [JournalTag]
    private let onEdit: (JournalRecord) -> Void
    private let onDeleted: () -> Void
    private let dateStyle = JournalDateStyle()

    // MARK: - Body

    init(
        record: JournalRecord,
        tags: [JournalTag],
        deleteJournal: any DeleteJournalUseCaseProtocol,
        errorHandler: ErrorHandler,
        onEdit: @escaping (JournalRecord) -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.record = record
        self.tags = tags
        self.onEdit = onEdit
        self.onDeleted = onDeleted
        _viewModel = State(
            initialValue: JournalDetailViewModel(
                record: record,
                deleteJournal: deleteJournal,
                errorHandler: errorHandler
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingM) {
                Text(dateStyle.timestampText(for: viewModel.record.writtenAt))
                    .hannunFont(.caption, tabularFigures: true)
                    .foregroundStyle(Color.textSecondary)

                Text(viewModel.record.title)
                    .hannunFont(.screenTitle)
                    .foregroundStyle(Color.textPrimary)

                tagRow

                if !viewModel.record.content.isEmpty {
                    Text(viewModel.record.content)
                        .hannunFont(.body)
                        .foregroundStyle(Color.textPrimary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .spacingL)
            .padding(.vertical, .spacingM)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(Constants.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alertPrompt(item: $viewModel.alertPrompt)
        .onChange(of: record) { viewModel.apply($1) }
        .onChange(of: viewModel.deletedEntryID) { _, deletedEntryID in
            guard deletedEntryID != nil else { return }
            onDeleted()
        }
    }

    /// 셀과 달리 상세에서는 태그를 3개로 줄이지 않는다 — 전문을 보러 들어온 화면이다.
    @ViewBuilder
    private var tagRow: some View {
        if !tags.isEmpty {
            ChipGroup {
                ForEach(tags) { tag in
                    TagPill(tag.name, category: tag.category)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(Constants.editTitle, systemImage: Constants.editSymbolName) {
                onEdit(viewModel.record)
            }
            .labelStyle(.iconOnly)
            .disabled(viewModel.isDeleting)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(
                Constants.deleteTitle,
                systemImage: Constants.deleteSymbolName,
                role: .destructive
            ) {
                viewModel.requestDelete()
            }
            .labelStyle(.iconOnly)
            .disabled(viewModel.isDeleting)
        }
    }
}

fileprivate enum Constants {
    static let screenTitle = "일지"
    static let editTitle = "수정"
    static let deleteTitle = "삭제"
    static let editSymbolName = "square.and.pencil"
    static let deleteSymbolName = "trash"
}
