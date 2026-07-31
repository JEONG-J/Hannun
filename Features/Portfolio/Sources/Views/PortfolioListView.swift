//
//  PortfolioListView.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 보유 종목 목록 (PF-1, PF-4).
///
/// 요약 바와 카테고리 칩은 리스트 밖에 고정한다 — glass 칩이 스크롤 콘텐츠 안으로 들어가면
/// 행이 지나갈 때마다 재질을 다시 계산한다.
struct PortfolioListView: View {

    // MARK: - Property

    @Environment(PortfolioRouter.self) private var router
    @Environment(\.appRouter) private var appRouter

    @State private var viewModel: PortfolioListViewModel

    private let container: DIContainer
    private let errorHandler: ErrorHandler

    // MARK: - Body

    @MainActor
    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        _viewModel = State(
            initialValue: PortfolioListViewModel(
                fetchHoldings: container.resolve((any FetchHoldingsUseCaseProtocol).self),
                deleteHolding: container.resolve((any DeleteHoldingUseCaseProtocol).self),
                exchangeRateService: container.resolve((any ExchangeRateServiceProtocol).self),
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
            .safeAreaInset(edge: .bottom) { accessory }
            .alertPrompt(item: $viewModel.alertPrompt)
            .sheet(item: $router.holdingEditor) { mode in
                HoldingEditorView(
                    container: container,
                    errorHandler: errorHandler,
                    mode: mode,
                    onSaved: { Task { await viewModel.refresh() } }
                )
            }
            .task {
                viewModel.apply(appRouter?.consumeRoute(for: .portfolio))
                await viewModel.load()
            }
            .onChange(of: appRouter?.pendingRoute) { _, pending in
                guard let route = pending ?? nil else { return }
                viewModel.apply(route)
                _ = appRouter?.consumeRoute(for: .portfolio)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.valuations {
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
        if viewModel.hasHoldings {
            VStack(spacing: .spacingM) {
                header

                if viewModel.sections.isEmpty {
                    filteredEmpty
                } else {
                    holdingList
                }
            }
        } else {
            EmptyStateView(
                systemImageName: "chart.pie",
                title: Constants.emptyTitle,
                message: Constants.emptyMessage,
                actionTitle: Constants.addHoldingTitle,
                action: { router.presentHoldingEditor(.create) }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            SummaryBar(
                title: viewModel.summaryTitle,
                amount: viewModel.summaryAmount,
                change: summaryChange
            )
            .padding(.horizontal, .spacingL)

            if viewModel.hasStaleQuotes {
                StaleBadge(message: Constants.staleMessage)
                    .padding(.horizontal, .spacingL)
            }

            categoryChips
        }
        .padding(.top, .spacingS)
    }

    private var categoryChips: some View {
        ChipGroup {
            FilterChip(
                Constants.allCategoriesTitle,
                isSelected: viewModel.selectedCategory == nil
            ) {
                viewModel.selectCategory(nil)
            }

            ForEach(AssetCategory.allCases, id: \.self) { category in
                FilterChip(
                    category.title,
                    isSelected: viewModel.selectedCategory == category,
                    tint: category.color
                ) {
                    viewModel.selectCategory(category)
                }
            }
        }
        .safeAreaPadding(.horizontal, .spacingL)
    }

    private var holdingList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    if viewModel.isExpanded(section.category) {
                        ForEach(section.valuations) { valuation in
                            row(for: valuation)
                        }
                    }
                } header: {
                    CategorySectionHeader(
                        category: section.category,
                        title: section.category.title,
                        subtotal: section.subtotal,
                        isExpanded: expansion(for: section.category)
                    )
                    .textCase(nil)
                    .listRowInsets(Constants.headerInsets)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    private var filteredEmpty: some View {
        VStack {
            EmptyStateView(
                systemImageName: "line.3.horizontal.decrease",
                title: Constants.filteredEmptyTitle,
                message: Constants.filteredEmptyMessage
            )

            Spacer(minLength: 0)
        }
    }

    /// 탭바 액세서리 자리. 앱 타깃이 `tabViewBottomAccessory` 를 열어 주면 그쪽으로 옮긴다.
    private var accessory: some View {
        BottomAccessory {
            AccessoryActionButton(Constants.addHoldingTitle, systemImageName: "plus") {
                router.presentHoldingEditor(.create)
            }

            Spacer(minLength: .spacingS)

            AccessoryActionButton(
                Constants.cashFlowTitle,
                systemImageName: "arrow.left.arrow.right",
                style: .secondary
            ) {
                router.showCashFlowList()
            }
        }
        .padding(.horizontal, .spacingL)
        .padding(.bottom, .spacingS)
    }

    private var summaryChange: ChangePillContent? {
        guard let profit = viewModel.summaryProfit,
              let returnRate = viewModel.summaryReturnRate
        else { return nil }

        return .amountWithRatio(profit, returnRate)
    }

    // MARK: - Function

    private func row(for valuation: HoldingValuation) -> some View {
        HoldingValuationRow(valuation: valuation, metric: viewModel.metric) {
            viewModel.cycleMetric()
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.surfacePrimary)
        .swipeActions(edge: .leading) {
            Button {
                router.presentHoldingEditor(.edit(valuation.holding))
            } label: {
                Label(Constants.editTitle, systemImage: "pencil")
            }
            .tint(Color.brand)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.requestDelete(valuation)
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

    private func expansion(for category: AssetCategory) -> Binding<Bool> {
        Binding(
            get: { viewModel.isExpanded(category) },
            set: { viewModel.setExpanded($0, for: category) }
        )
    }
}

fileprivate enum Constants {
    static let screenTitle = "포트폴리오"
    static let allCategoriesTitle = "전체"
    static let addHoldingTitle = "종목 추가"
    static let cashFlowTitle = "입출금 기록"
    static let editTitle = "수정"
    static let deleteTitle = "삭제"
    static let retryTitle = "다시 시도"
    static let failureTitle = "불러오지 못했어요"
    static let emptyTitle = "아직 등록한 종목이 없어요"
    static let emptyMessage = "보유 중인 현금과 종목을 넣으면 평가금액을 계산해 드려요."
    static let filteredEmptyTitle = "이 카테고리에는 종목이 없어요"
    static let filteredEmptyMessage = "다른 카테고리를 골라 보세요."
    static let staleMessage = "갱신 실패 · 마지막 시세 기준"
    static let headerInsets = EdgeInsets(
        top: .spacingS,
        leading: .spacingL,
        bottom: .spacingS,
        trailing: .spacingL
    )
}
