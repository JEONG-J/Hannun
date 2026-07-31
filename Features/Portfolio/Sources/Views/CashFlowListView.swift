//
//  CashFlowListView.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 입출금 기록 목록 (PF-5, PF-6). 월별로 묶어 최근 달을 위에 둔다.
struct CashFlowListView: View {

    // MARK: - Property

    @Environment(PortfolioRouter.self) private var router

    @State private var viewModel: CashFlowListViewModel

    private let container: DIContainer
    private let errorHandler: ErrorHandler

    // MARK: - Body

    @MainActor
    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        _viewModel = State(
            initialValue: CashFlowListViewModel(
                manageCashFlow: container.resolve((any ManageCashFlowUseCaseProtocol).self),
                errorHandler: errorHandler
            )
        )
    }

    var body: some View {
        @Bindable var router = router

        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle(Constants.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.presentCashFlowEditor(.create)
                    } label: {
                        Label(Constants.addTitle, systemImage: "plus")
                    }
                }
            }
            .alertPrompt(item: $viewModel.alertPrompt)
            .sheet(item: $router.cashFlowEditor) { mode in
                CashFlowEditorView(
                    container: container,
                    errorHandler: errorHandler,
                    mode: mode,
                    onSaved: { Task { await viewModel.refresh() } }
                )
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.events {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            loaded
        case .failed(let error):
            failure(error)
        }
    }

    @ViewBuilder
    private var loaded: some View {
        if viewModel.isEmpty {
            EmptyStateView(
                systemImageName: "arrow.left.arrow.right",
                title: Constants.emptyTitle,
                message: Constants.emptyMessage,
                actionTitle: Constants.addTitle,
                action: { router.presentCashFlowEditor(.create) }
            )
        } else {
            eventList
        }
    }

    private var eventList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.events) { event in
                        row(for: event)
                    }
                } header: {
                    Text(section.title)
                        .hannunFont(.subtext)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .textCase(nil)
                        .listRowInsets(Constants.headerInsets)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Function

    private func row(for event: CashFlowRecord) -> some View {
        CashFlowRow(event: event)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.surfacePrimary)
            .swipeActions(edge: .leading) {
                Button {
                    router.presentCashFlowEditor(.edit(event))
                } label: {
                    Label(Constants.editTitle, systemImage: "pencil")
                }
                .tint(Color.brand)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    viewModel.requestDelete(event)
                } label: {
                    Label(Constants.deleteTitle, systemImage: "trash")
                }
            }
    }

    private func failure(_ error: AppError) -> some View {
        EmptyStateView(
            systemImageName: "exclamationmark.triangle",
            title: Constants.failureTitle,
            message: error.userMessage,
            actionTitle: Constants.retryTitle,
            action: { Task { await viewModel.refresh() } }
        )
    }
}

fileprivate enum Constants {
    static let screenTitle = "입출금 기록"
    static let addTitle = "기록 추가"
    static let editTitle = "수정"
    static let deleteTitle = "삭제"
    static let retryTitle = "다시 시도"
    static let failureTitle = "불러오지 못했어요"
    static let emptyTitle = "입출금 기록이 없어요"
    static let emptyMessage = "예치·인출을 기록하면 성과 탭이 원금 변동을 빼고 수익률을 계산해요."
    static let headerInsets = EdgeInsets(
        top: .spacingS,
        leading: .spacingL,
        bottom: .spacingS,
        trailing: .spacingL
    )
}
