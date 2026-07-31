//
//  JournalListView.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 일지 목록 화면이자 탭 전용 `NavigationStack` 의 소유자 (JR-1, JR-4).
struct JournalListView: View {
    // MARK: - Property

    @State private var viewModel: JournalListViewModel
    @State private var router = JournalRouter()

    private let container: DIContainer
    private let errorHandler: ErrorHandler
    private let dateStyle = JournalDateStyle()

    // MARK: - Body

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        _viewModel = State(
            initialValue: JournalListViewModel(
                fetchJournal: container.resolve((any FetchJournalUseCaseProtocol).self),
                fetchHoldings: container.resolve((any FetchHoldingsUseCaseProtocol).self)
            )
        )
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
                .navigationTitle(Constants.screenTitle)
                .navigationDestination(for: JournalRoute.self, destination: detail(for:))
                .searchable(text: $viewModel.searchText, prompt: Constants.searchPrompt)
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.journal) {
            JournalComposeAccessory { router.composeNewEntry() }
        }
        .fullScreenCover(item: $router.composition, content: compose(for:))
        .task { await viewModel.load() }
    }

    private var content: some View {
        VStack(spacing: .spacingM) {
            holdingFilterRow
            entryArea
        }
        .padding(.top, .spacingS)
    }

    /// 종목 필터는 목록 로딩 상태와 함께 사라지지 않는다 — 필터를 바꾸는 동안
    /// 방금 누른 칩이 화면에서 없어지면 무엇을 고른 상태인지 알 수 없다.
    @ViewBuilder
    private var holdingFilterRow: some View {
        if let holdings = viewModel.holdingTagsState.value, !holdings.isEmpty {
            ChipGroup {
                FilterChip(
                    Constants.allHoldingsTitle,
                    isSelected: viewModel.selectedHoldingID == nil
                ) {
                    Task { await viewModel.selectHolding(nil) }
                }

                ForEach(holdings) { holding in
                    FilterChip(
                        holding.name,
                        isSelected: viewModel.selectedHoldingID == holding.id
                    ) {
                        Task { await viewModel.selectHolding(holding.id) }
                    }
                }
            }
            .padding(.horizontal, .spacingL)
        }
    }

    @ViewBuilder
    private var entryArea: some View {
        switch viewModel.entriesState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if let placeholder = viewModel.placeholder {
                placeholderView(placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                entryList
            }
        case let .failed(error):
            EmptyStateView(
                systemImageName: Constants.loadFailureSymbolName,
                title: Constants.loadFailureTitle,
                message: error.userMessage,
                actionTitle: Constants.retryTitle
            ) {
                Task { await viewModel.reload() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var entryList: some View {
        List(viewModel.visibleEntries) { entry in
            Button {
                router.showDetail(of: entry)
            } label: {
                JournalCell(
                    dateText: dateStyle.listText(for: entry.writtenAt),
                    title: entry.title,
                    preview: entry.content,
                    tags: viewModel.tagNames(for: entry)
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(Constants.entryRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .listRowSpacing(.spacingM)
        .scrollContentBackground(.hidden)
        // 액세서리 캡슐이 마지막 셀을 가리지 않도록 하단을 띄운다 (UI 스펙 §3.1).
        .safeAreaPadding(.bottom, .spacingXL)
    }

    // MARK: - Function

    @ViewBuilder
    private func placeholderView(_ placeholder: JournalListPlaceholder) -> some View {
        switch placeholder {
        case .noEntry:
            EmptyStateView(
                systemImageName: Constants.emptySymbolName,
                title: Constants.emptyTitle,
                message: Constants.emptyMessage
            )
        case .noMatch:
            EmptyStateView(
                systemImageName: Constants.noMatchSymbolName,
                title: Constants.noMatchTitle,
                message: Constants.noMatchMessage
            )
        }
    }

    private func detail(for route: JournalRoute) -> some View {
        switch route {
        case let .detail(record):
            JournalDetailView(
                record: record,
                tagNames: viewModel.tagNames(for: record),
                deleteJournal: container.resolve((any DeleteJournalUseCaseProtocol).self),
                errorHandler: errorHandler,
                onEdit: { router.edit($0) },
                onDeleted: {
                    router.closeDetail()
                    Task { await viewModel.reload() }
                }
            )
        }
    }

    private func compose(for composition: JournalComposition) -> some View {
        JournalComposeView(
            composition: composition,
            saveJournal: container.resolve((any SaveJournalUseCaseProtocol).self),
            fetchHoldings: container.resolve((any FetchHoldingsUseCaseProtocol).self),
            onClose: { router.dismissComposition() },
            onSaved: { saved in
                router.dismissComposition()
                router.refreshDetail(with: saved)
                Task { await viewModel.load() }
            }
        )
    }
}

fileprivate enum Constants {
    static let screenTitle = "매매일지"
    static let searchPrompt = "제목·본문 검색"
    static let allHoldingsTitle = "전체"

    static let emptySymbolName = "book.closed"
    static let emptyTitle = "첫 매매일지를 남겨보세요"
    static let emptyMessage = "왜 샀는지 적어두면 다음 판단이 쉬워집니다."

    static let noMatchSymbolName = "magnifyingglass"
    static let noMatchTitle = "조건에 맞는 일지가 없어요"
    static let noMatchMessage = "검색어나 종목 필터를 바꿔보세요."

    static let loadFailureSymbolName = "exclamationmark.triangle"
    static let loadFailureTitle = "일지를 불러오지 못했어요"
    static let retryTitle = "다시 시도"

    /// 셀 사이 간격은 `listRowSpacing` 이 만든다 — 행 인셋은 좌우 여백만 맡는다.
    static let entryRowInsets = EdgeInsets(
        top: 0,
        leading: .spacingL,
        bottom: 0,
        trailing: .spacingL
    )
}
