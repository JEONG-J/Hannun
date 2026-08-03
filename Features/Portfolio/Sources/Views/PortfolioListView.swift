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
/// 요약 바와 카테고리 카드는 시안 §6.2 의 한 콘텐츠 열이다 — 패딩 `[12, 16, 0, 16]`, gap 12.
/// 카드 모서리·행 좌우 여백·구분선이 끊기는 위치를 전부 코드가 정해야 해서 `List` 를 쓰지
/// 않는다. `List` 의 섹션 모델은 헤더를 행 배경 바깥에 두므로 헤더와 행이 카드 하나를
/// 공유하는 시안 구조를 만들 수 없다. 대신 잃은 `swipeActions` 는 행 `contextMenu` 가 받는다.
///
/// 필터 칩만 스크롤 밖에 고정한다 — glass 칩이 스크롤 콘텐츠 안으로 들어가면 행이 지나갈
/// 때마다 재질을 다시 계산한다.
struct PortfolioListView: View {

    // MARK: - Property

    @Environment(PortfolioRouter.self) private var router
    @Environment(\.appRouter) private var appRouter

    /// 탭 루트가 소유한다 — 하단 액세서리도 같은 인스턴스를 읽어야 하기 때문이다.
    @Bindable private var viewModel: PortfolioListViewModel

    private let container: DIContainer
    private let errorHandler: ErrorHandler

    // MARK: - Body

    init(
        viewModel: PortfolioListViewModel,
        container: DIContainer,
        errorHandler: ErrorHandler
    ) {
        _viewModel = Bindable(viewModel)
        self.container = container
        self.errorHandler = errorHandler
    }

    var body: some View {
        @Bindable var router = router

        searchableContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle(Constants.screenTitle)
            .toolbar {
                sortToolbarItem
                cashFlowToolbarItem
            }
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

    /// 종목이 하나도 없으면 검색창을 아예 달지 않는다 — 신규 설치 사용자가 처음 보는 화면이
    /// 그 화면인데, 거기 놓인 돋보기는 눌러도 걸릴 게 없다.
    ///
    /// 분기를 `content` 만 감싸는 안쪽에 두는 이유는 `task`·`sheet` 때문이다. 바깥 modifier
    /// 체인이 그대로 남아야 첫 종목이 들어와 검색창이 생길 때 화면 로딩이 다시 돌지 않는다.
    @ViewBuilder
    private var searchableContent: some View {
        if viewModel.hasHoldings {
            content
                .searchable(text: searchQuery, prompt: Constants.searchPrompt)
                // 검색창을 펼친 채 두면 목록 위 한 줄을 상시로 먹는다. 최소화하면 오른쪽 위
                // 돋보기 버튼으로 접혀 시안의 콘텐츠 열이 그대로 남는다.
                .searchToolbarBehavior(.minimize)
        } else {
            content
        }
    }

    /// 정렬은 "지금 보고 있는 목록이 어떤 상태인가" 라 왼쪽에 둔다. 오른쪽 검색·입출금은
    /// 새 작업을 여는 컨트롤이라 성격이 다르다. 정렬할 종목이 없으면 검색과 함께 사라진다.
    @ToolbarContentBuilder
    private var sortToolbarItem: some ToolbarContent {
        if viewModel.hasHoldings {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker(Constants.sortTitle, selection: $viewModel.sortOrder) {
                        ForEach(HoldingSortOrder.allCases) { order in
                            Label(order.title, systemImage: order.symbolName)
                                .tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(Constants.sortTitle, systemImage: sortSymbolName)
                }
                // 아이콘만으로는 "정렬을 건드렸다" 까지만 말한다. 무엇으로 정렬했는지는
                // 눈으로 메뉴를 열어 봐야 알 수 있어서, 음성으로는 값을 직접 읽어 준다.
                .accessibilityValue(viewModel.sortOrder.title)
            }
        }
    }

    /// 기본 순서를 벗어나면 채운 아이콘으로 바꾼다 — 정렬은 카드 안 행 순서만 조용히 바꾸므로
    /// 표시가 없으면 "왜 순서가 이렇지" 로 남는다.
    private var sortSymbolName: String {
        viewModel.isSortAdjusted
            ? Constants.adjustedSortSymbolName
            : Constants.sortSymbolName
    }

    /// `searchText` 를 직접 묶지 않는 이유는 검색이 시작될 때 접힌 카드를 펴야 하기 때문이다.
    /// 그 판단을 ViewModel 이 들고 있어야 화면 밖에서도 같은 동작이 재현된다.
    private var searchQuery: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.search($0) }
        )
    }

    /// 입출금 기록(PF-5/6)의 진입점. 하단 액세서리에서 여기로 돌아왔다 — 캡슐 오른쪽은
    /// 컨트롤 하나의 자리이고, 종목 추가와 달리 입출금은 매일 쓰는 액션이 아니다
    /// (디자인 문서 §4.2 · §11-1).
    private var cashFlowToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                router.showCashFlowList()
            } label: {
                Label(Constants.cashFlowTitle, systemImage: Constants.cashFlowSymbolName)
            }
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
            VStack(spacing: 0) {
                activeFilterChips

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

    /// 시안 §6.2 에 칩 줄은 없다. 순자산 탭에서 카테고리를 물고 들어오는 NW-4 경로 때문에만
    /// 남긴 요소라, 지금 무엇으로 걸러져 있는지 알리고 되돌릴 자리가 필요한 동안에만 그린다.
    /// 필터를 풀면 줄 자체가 사라져 기본 화면은 시안과 같아진다.
    @ViewBuilder
    private var activeFilterChips: some View {
        if let selectedCategory = viewModel.selectedCategory {
            ChipGroup(scrollsHorizontally: false) {
                FilterChip(Constants.allCategoriesTitle, isSelected: false) {
                    viewModel.selectCategory(nil)
                }

                FilterChip(
                    selectedCategory.title,
                    isSelected: true,
                    tint: selectedCategory.color
                ) {
                    viewModel.selectCategory(nil)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, .spacingL)
            .padding(.top, .spacingM)
        }
    }

    /// 시안 §6.2 콘텐츠 열: 패딩 `[12, 16, 0, 16]` · gap 12. 요약 바도 카테고리 카드와 같은
    /// surface 카드라 같은 스택에 형제로 놓는다.
    private var holdingList: some View {
        ScrollView {
            LazyVStack(spacing: .spacingM) {
                SummaryBar(
                    title: viewModel.summaryTitle,
                    amount: viewModel.summaryAmount,
                    change: summaryChange
                )

                if viewModel.hasStaleQuotes {
                    StaleBadge(message: Constants.staleMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(viewModel.sections) { section in
                    PortfolioCategoryCard(
                        section: section,
                        metric: viewModel.metric,
                        isExpanded: expansion(for: section.category),
                        onMetricTap: { viewModel.cycleMetric() },
                        onEdit: { router.presentHoldingEditor(.edit($0.holding)) },
                        onDelete: { viewModel.requestDelete($0) }
                    )
                }
            }
            .padding(.top, .spacingM)
            .padding(.horizontal, .spacingL)
        }
        .refreshable { await viewModel.refresh() }
        // 액세서리 캡슐이 마지막 카드를 가리지 않도록 하단을 띄운다 (UI 스펙 §3.1).
        .safeAreaPadding(.bottom, .spacingXL)
    }

    /// 요약 바를 함께 띄우지 않는다 — 걸러진 카테고리가 비었다는 말과 "₩0" 은 같은 말이라
    /// 두 번 하면 빈 상태 문구가 묻힌다.
    ///
    /// 검색 중인지에 따라 문구를 갈아 끼운다. "다른 카테고리를 골라 보세요" 는 검색어를
    /// 넣은 사람에게는 손댈 곳을 잘못 가리킨다.
    private var filteredEmpty: some View {
        let isSearching = viewModel.isSearching

        return VStack {
            EmptyStateView(
                systemImageName: isSearching
                    ? Constants.searchEmptySymbolName
                    : Constants.filteredEmptySymbolName,
                title: isSearching ? Constants.searchEmptyTitle : Constants.filteredEmptyTitle,
                message: isSearching ? Constants.searchEmptyMessage : Constants.filteredEmptyMessage
            )

            Spacer(minLength: 0)
        }
    }

    private var summaryChange: ChangePillContent? {
        guard let profit = viewModel.summaryProfit,
              let returnRate = viewModel.summaryReturnRate
        else { return nil }

        return .amountWithRatio(profit, returnRate)
    }

    // MARK: - Function

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
    static let cashFlowTitle = "입출금 기록"
    static let cashFlowSymbolName = "arrow.left.arrow.right"
    static let searchPrompt = "종목명·티커 검색"
    static let sortTitle = "정렬"
    static let sortSymbolName = "arrow.up.arrow.down.circle"
    static let adjustedSortSymbolName = "arrow.up.arrow.down.circle.fill"
    static let allCategoriesTitle = "전체"
    static let addHoldingTitle = "종목 추가"
    static let retryTitle = "다시 시도"
    static let failureTitle = "불러오지 못했어요"
    static let emptyTitle = "아직 등록한 종목이 없어요"
    static let emptyMessage = "보유 중인 현금과 종목을 넣으면 평가금액을 계산해 드려요."
    static let filteredEmptySymbolName = "line.3.horizontal.decrease"
    static let filteredEmptyTitle = "이 카테고리에는 종목이 없어요"
    static let filteredEmptyMessage = "위 '전체'를 누르면 모든 종목을 볼 수 있어요."
    static let searchEmptySymbolName = "magnifyingglass"
    static let searchEmptyTitle = "검색 결과가 없어요"
    static let searchEmptyMessage = "종목명이나 티커의 일부만 넣어도 찾을 수 있어요."
    static let staleMessage = "갱신 실패 · 마지막 시세 기준"
}
