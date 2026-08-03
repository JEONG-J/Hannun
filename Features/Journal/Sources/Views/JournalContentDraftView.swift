//
//  JournalContentDraftView.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunCore
import HannunDesignSystem
import SwiftUI

/// 본문 초안 화면 (JR-2).
///
/// Apple Intelligence 가 쓴 문장을 **본문에 바로 앉히지 않고 여기서 한 번 보여 준다.**
/// 매매일지 본문은 나중에 판단의 근거로 다시 읽히는 글이라, 내가 쓰지 않은 문장이 확인 없이
/// 들어가면 무엇이 내 기억이고 무엇이 모델의 문장인지 구분할 길이 사라진다.
///
/// 화면은 위에서 아래로 한 방향이다 — 메모를 적고, 만들고, 읽고, 넣는다. 만들기 전에는
/// 초안 섹션이 아예 없어서 다음에 할 일이 늘 화면 맨 아래에 있다.
struct JournalContentDraftView: View {

    // MARK: - Property

    /// 메모 한 칸만 여기서 쓴다 — 작성 폼의 상태를 그대로 이어받아야 화면을 닫았다 열어도
    /// 적어 둔 게 남는다.
    @Bindable private var viewModel: JournalComposeViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMemoFocused: Bool

    // MARK: - Body

    init(viewModel: JournalComposeViewModel) {
        _viewModel = Bindable(viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                memoSection
                requestSection

                if let draft = viewModel.contentDraft {
                    draftSection(draft)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimary)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Function

    /// 폼이 이미 들고 있는 제목·시각·종목은 다시 묻지 않는다. 여기서 받는 건 그것만으로는
    /// 알 수 없는 **왜** 하나뿐이라 입력도 하나다.
    private var memoSection: some View {
        Section {
            TextField(Constants.memoPlaceholder, text: $viewModel.draftMemo, axis: .vertical)
                .hannunFont(.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(Constants.memoLineLimit, reservesSpace: true)
                .focused($isMemoFocused)
        } header: {
            sectionHeader(Constants.memoSectionTitle)
        } footer: {
            Text(Constants.privacyNotice)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    private var requestSection: some View {
        Section {
            if viewModel.isDraftingContent {
                progressRow
            } else {
                requestButton
            }

            if let failure = viewModel.contentDraftFailure {
                failureLabel(failure)
            }
        }
        .listRowBackground(Color.surfacePrimary)
    }

    private var progressRow: some View {
        HStack(spacing: .spacingS) {
            ProgressView()

            Text(Constants.draftingText)
                .hannunFont(.body)
                .foregroundStyle(Color.textSecondary)
        }
    }

    /// 심볼만 무지개로 두고 글자는 토큰 색을 쓴다. 툴바 입구와 같은 표식을 세워 두 자리가
    /// 한 기능이라는 걸 말하되, 문장까지 시스템 색으로 칠하면 폼 안의 다른 행과 목소리가 갈린다.
    private var requestButton: some View {
        Button {
            isMemoFocused = false
            Task { await viewModel.requestContentDraft() }
        } label: {
            HStack(spacing: .spacingS) {
                Image(systemName: Constants.requestSymbolName)
                    .foregroundStyle(.intelligence)

                Text(requestTitle)
                    .foregroundStyle(Color.brand)
            }
            .hannunFont(.body)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canRequestContentDraft)
    }

    /// 이미 초안이 하나 있으면 같은 버튼이 "다시" 를 말한다 — 누르면 지금 읽고 있는 초안이
    /// 새 문장으로 바뀐다는 뜻이라 문구가 달라야 한다.
    private var requestTitle: String {
        viewModel.contentDraft == nil ? Constants.requestTitle : Constants.retryTitle
    }

    private func draftSection(_ draft: String) -> some View {
        Section {
            Text(draft)
                .hannunFont(.body)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            applyButton
        } header: {
            sectionHeader(Constants.draftSectionTitle)
        } footer: {
            Text(Constants.reviewNotice)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    /// 쓰던 본문이 있으면 "넣기" 가 아니라 "바꾸기" 다. 들어가는 순간 앞 문장이 사라지므로
    /// 확인 다이얼로그 대신 버튼 문구가 먼저 말하게 한다.
    private var applyButton: some View {
        Button {
            viewModel.applyContentDraft()
            dismiss()
        } label: {
            Label(applyTitle, systemImage: Constants.applySymbolName)
                .hannunFont(.body)
                .foregroundStyle(Color.brand)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var applyTitle: String {
        viewModel.draftReplacesContent ? Constants.replaceTitle : Constants.applyTitle
    }

    private func failureLabel(_ failure: AppError) -> some View {
        Label(failure.userMessage, systemImage: Constants.failureSymbolName)
            .hannunFont(.caption)
            .foregroundStyle(Color.warning)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(nil)
    }

    /// 닫기 하나뿐이다. 이 화면의 확인은 초안 옆에 붙어 있어야 뜻이 서므로(무엇을 넣는지
    /// 읽으면서 눌러야 한다) 툴바 오른쪽으로 떼어 놓지 않는다.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Constants.closeTitle, systemImage: Constants.closeSymbolName) {
                viewModel.discardContentDraft()
                dismiss()
            }
            .labelStyle(.iconOnly)
            .disabled(viewModel.isDraftingContent)
        }
    }
}

fileprivate enum Constants {
    static let title = "본문 초안"
    static let closeTitle = "닫기"
    static let closeSymbolName = "xmark"

    static let memoSectionTitle = "메모"
    static let memoPlaceholder = "왜 그렇게 판단했는지 몇 마디만 남겨보세요"
    static let memoLineLimit = 4
    static let privacyNotice = "제목·작성 시각·연결 종목과 이 메모를 재료로 씁니다. "
        + "기기 안에서 처리되고 밖으로 나가지 않아요."

    static let requestTitle = "초안 만들기"
    static let retryTitle = "다시 만들기"
    static let requestSymbolName = "apple.intelligence"
    static let draftingText = "초안을 쓰는 중이에요"

    static let draftSectionTitle = "초안"
    static let reviewNotice = "지어낸 숫자가 없는지 확인하고 넣어주세요. 넣은 뒤에도 고칠 수 있어요."
    static let applyTitle = "본문에 넣기"
    static let replaceTitle = "본문 바꾸기"
    static let applySymbolName = "arrow.down.doc"

    static let failureSymbolName = "exclamationmark.circle"
}
