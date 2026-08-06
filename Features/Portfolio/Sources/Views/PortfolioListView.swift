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
/// 필터 칩 줄만 세로 스크롤 밖에 고정한다 — glass 칩이 목록 콘텐츠 안으로 들어가면 행이
/// 지나갈 때마다 재질을 다시 계산한다. 칩 줄 자체의 가로 스크롤은 그 바깥에서 따로 돈다.
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
                listControlToolbarItem
                addHoldingToolbarItem
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

    /// 왼쪽은 "지금 보고 있는 목록이 어떤 상태인가" 를 다루는 자리다. 정렬과 카테고리 필터는
    /// 둘 다 새 작업을 열지 않고 눈앞의 목록만 손보는 조작이라 메뉴 하나로 합쳐 둔다.
    /// 종목이 없으면 정렬할 것도 거를 것도 없어서 검색창과 함께 사라진다.
    @ToolbarContentBuilder
    private var listControlToolbarItem: some ToolbarContent {
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

                    categoryFilterMenu
                } label: {
                    Label(Constants.listControlTitle, systemImage: listControlSymbolName)
                }
                .accessibilityValue(listControlAccessibilityValue)
            }
        }
    }

    /// 카테고리를 정렬과 같은 층에 펼치면 여섯 줄이 더 붙어 메뉴 하나가 화면 절반을 먹는다.
    /// 한 겹 접어 두면 부모 메뉴는 "정렬 세 줄 + 카테고리 한 줄" 로 읽히고, 거를 때만 안으로
    /// 들어가면 된다 — 정렬은 열 때마다 쓰지만 필터는 가끔 쓴다.
    ///
    /// 접은 대가로 무엇이 걸려 있는지가 밖에서 안 보이므로 라벨이 대신 말한다. 둘까지는 이름을
    /// 그대로 붙이고 그보다 많으면 개수로 줄인다 — 다섯 이름을 다 이으면 메뉴 폭에서 잘린다.
    ///
    /// 안쪽은 동시에 여러 개를 켤 수 있어 `Picker` 가 아니라 `Toggle` 이다 — 메뉴 안 `Toggle`
    /// 은 체크마크로 그려져 `Picker` 와 같은 결로 읽히면서 다중 선택을 표현한다. 행마다
    /// 카테고리 심볼만 얹고 색은 넣지 않는다. 메뉴 행은 시스템이 그리는 영역이라 색이 반영된다는
    /// 보장이 없고, 카테고리 색은 아래 필터 칩의 범례 dot 이 이미 나른다.
    private var categoryFilterMenu: some View {
        Menu {
            Toggle(isOn: allCategoriesSelection) {
                Text(Constants.allCategoriesTitle)
            }

            ForEach(AssetCategory.allCases, id: \.self) { category in
                Toggle(isOn: categorySelection(for: category)) {
                    Label(category.title, systemImage: category.systemImageName)
                }
            }
        } label: {
            Label(categoryFilterTitle, systemImage: Constants.categoryFilterSymbolName)
        }
    }

    private var categoryFilterTitle: String {
        let selected = viewModel.selectedCategoryList
        guard !selected.isEmpty else { return Constants.categoryFilterTitle }

        let summary = selected.count > Constants.inlineCategoryNameLimit
            ? "\(selected.count)\(Constants.categoryCountUnit)"
            : selected.map(\.title).joined(separator: Constants.categoryListSeparator)

        return Constants.categoryFilterTitle + Constants.sortFilterSeparator + summary
    }

    /// 정렬이든 필터든 기본값을 벗어나면 채운 아이콘으로 바꾼다 — 둘 다 목록을 조용히
    /// 뒤섞거나 줄이기만 해서, 표시가 없으면 "왜 이것만 이 순서로 보이지" 가 남는다.
    private var listControlSymbolName: String {
        viewModel.isSortAdjusted || viewModel.isCategoryFiltered
            ? Constants.adjustedListControlSymbolName
            : Constants.listControlSymbolName
    }

    /// 아이콘은 "건드렸다" 까지만 말한다. 무엇으로 정렬했고 무엇만 남겼는지는 메뉴를 열어야
    /// 보이므로, 음성으로는 두 값을 이어 붙여 한 번에 읽어 준다.
    private var listControlAccessibilityValue: String {
        guard viewModel.isCategoryFiltered else { return viewModel.sortOrder.title }

        let categories = viewModel.selectedCategoryList
            .map(\.title)
            .joined(separator: Constants.categoryListSeparator)

        return viewModel.sortOrder.title + Constants.sortFilterSeparator + categories
    }

    /// "전체" 는 여섯 번째 카테고리가 아니라 필터 해제 버튼이다. 그래도 `Toggle` 로 두는 건
    /// 옆 행들과 체크마크 열을 맞추기 위해서고, 이미 켜진 상태에서 다시 눌러도 해제가 곧
    /// 무필터라 결과가 같다.
    private var allCategoriesSelection: Binding<Bool> {
        Binding(
            get: { !viewModel.isCategoryFiltered },
            set: { _ in viewModel.clearCategoryFilter() }
        )
    }

    /// `searchText` 를 직접 묶지 않는 이유는 검색이 시작될 때 접힌 카드를 펴야 하기 때문이다.
    /// 그 판단을 ViewModel 이 들고 있어야 화면 밖에서도 같은 동작이 재현된다.
    private var searchQuery: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.search($0) }
        )
    }

    /// 종목 추가(PF-2)의 진입점. 이 화면에서 가장 잦은 액션이라 목록이 비었든 찼든 오른쪽
    /// 위 같은 자리를 지킨다 — 툴바가 화면 상태에 따라 움직이면 손이 자리를 다시 찾아야 한다.
    /// 자리를 물려준 입출금 기록은 하단 액세서리로 내려갔다. 매일 쓰는 액션이 아니라
    /// 상시 노출까지는 필요 없다.
    private var addHoldingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                router.presentHoldingEditor(.create)
            } label: {
                Label(Constants.addHoldingTitle, systemImage: Constants.addHoldingSymbolName)
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

    /// 시안 §6.2 에 칩 줄은 없다. 순자산 탭에서 카테고리를 물고 들어오는 NW-4 경로와 좌상단
    /// 메뉴가 걸어 둔 필터를 되돌릴 자리가 필요한 동안에만 그린다. 필터를 풀면 줄 자체가
    /// 사라져 기본 화면은 시안과 같아진다.
    ///
    /// 선택이 다중이 되면서 가로 스크롤을 켰다 — 다섯 카테고리를 다 켜면 "전체" 까지 여섯
    /// 칩이라 한 줄에 들어가지 않는다. 스크롤이 없으면 뒤쪽 칩이 잘려 그 카테고리만 골라
    /// 끄지 못한다.
    @ViewBuilder
    private var activeFilterChips: some View {
        if viewModel.isCategoryFiltered {
            ChipGroup {
                FilterChip(Constants.allCategoriesTitle, isSelected: false) {
                    viewModel.clearCategoryFilter()
                }

                // 켜진 칩을 누르면 그 카테고리 하나만 빠진다. 나머지 선택은 그대로 남아야
                // 여러 개를 켜 둔 사람이 하나씩 좁혀 갈 수 있다.
                ForEach(viewModel.selectedCategoryList, id: \.self) { category in
                    FilterChip(category.title, isSelected: true, tint: category.color) {
                        viewModel.toggleCategory(category)
                    }
                }
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
    ///
    /// 되돌리는 버튼을 화면 안에 둔다. 칩 줄은 카테고리 필터일 때만 그려지고 검색창은
    /// 최소화되어 접히므로, 검색어만 걸린 0건 화면에는 되돌릴 자리가 하나도 남지 않는다.
    /// 둘 다 걸렸으면 검색어를 먼저 푼다 — 그래도 0건이면 다음 화면이 필터 해제를 내민다.
    private var filteredEmpty: some View {
        let isSearching = viewModel.isSearching

        return EmptyStateView(
            systemImageName: isSearching
                ? Constants.searchEmptySymbolName
                : Constants.filteredEmptySymbolName,
            title: isSearching ? Constants.searchEmptyTitle : Constants.filteredEmptyTitle,
            message: isSearching ? Constants.searchEmptyMessage : Constants.filteredEmptyMessage,
            actionTitle: isSearching
                ? Constants.clearSearchTitle
                : Constants.clearCategoryFilterTitle
        ) {
            if isSearching {
                viewModel.search("")
            } else {
                viewModel.clearCategoryFilter()
            }
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

    /// 새 값을 버리고 `toggleCategory` 를 부른다 — `Toggle` 이 넘기는 값은 현재 상태의 반전
    /// 이고 그 반전이 곧 이 함수가 하는 일이라, 값을 받아 쓰면 같은 뒤집기를 두 번 적는 셈이다.
    private func categorySelection(for category: AssetCategory) -> Binding<Bool> {
        Binding(
            get: { viewModel.isCategorySelected(category) },
            set: { _ in viewModel.toggleCategory(category) }
        )
    }
}

fileprivate enum Constants {
    static let screenTitle = "포트폴리오"
    static let addHoldingTitle = "종목 추가"
    static let addHoldingSymbolName = "plus"
    static let searchPrompt = "종목명·티커 검색"
    static let listControlTitle = "정렬 및 필터"
    static let listControlSymbolName = "line.3.horizontal.decrease.circle"
    static let adjustedListControlSymbolName = "line.3.horizontal.decrease.circle.fill"
    static let sortTitle = "정렬"
    static let categoryFilterTitle = "카테고리"
    static let categoryFilterSymbolName = "line.3.horizontal.decrease"
    /// 하위 메뉴 라벨에 이름을 그대로 늘어놓을 수 있는 개수. 넘으면 개수로 줄인다.
    static let inlineCategoryNameLimit = 2
    static let categoryCountUnit = "개"
    /// 정렬 값과 필터 목록을 잇는 구분자. 하위 메뉴 라벨과 음성 안내가 함께 쓴다.
    static let sortFilterSeparator = " · "
    static let categoryListSeparator = ", "
    static let allCategoriesTitle = "전체"
    static let retryTitle = "다시 시도"
    static let failureTitle = "불러오지 못했어요"
    static let emptyTitle = "아직 등록한 종목이 없어요"
    static let emptyMessage = "보유 중인 현금과 종목을 넣으면 평가금액을 계산해 드려요."
    static let filteredEmptySymbolName = "line.3.horizontal.decrease"
    static let filteredEmptyTitle = "고른 카테고리에 종목이 없어요"
    static let filteredEmptyMessage = "필터를 풀면 모든 종목을 볼 수 있어요."
    static let clearCategoryFilterTitle = "필터 해제"
    static let searchEmptySymbolName = "magnifyingglass"
    static let searchEmptyTitle = "검색 결과가 없어요"
    static let searchEmptyMessage = "종목명이나 티커의 일부만 넣어도 찾을 수 있어요."
    static let clearSearchTitle = "검색어 지우기"
}
