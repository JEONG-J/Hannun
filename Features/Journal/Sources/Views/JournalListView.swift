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
///
/// 스크롤 영역 위에 고정 행을 두지 않는다 — 목록 바깥에 한 줄이라도 얹으면 스크롤이 그 줄
/// **아래에서만** 일어나 큰 제목이 걷히지 않고, 화면이 두 조각으로 나뉘어 움직인다.
/// 그래서 종목 필터 칩 줄을 왼쪽 툴바 메뉴로, 검색을 오른쪽 툴바 버튼으로 올렸다.
/// 콘텐츠가 목록 하나뿐이 되면서 제목·툴바가 스크롤에 맞춰 함께 접힌다.
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
            entryArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
                .navigationTitle(Constants.screenTitle)
                .navigationSubtitle(subtitleText)
                .navigationDestination(for: JournalRoute.self, destination: detail(for:))
                .toolbar { holdingFilterItem }
                .searchable(text: $viewModel.searchText, prompt: Constants.searchPrompt)
                // 펼친 검색창은 목록 위 한 줄을 상시로 먹는다. 최소화하면 오른쪽 위
                // 돋보기 버튼으로 접혀 콘텐츠 열이 목록 하나로 남는다 (포트폴리오 탭과 같은 규칙).
                .searchToolbarBehavior(.minimize)
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.journal) {
            JournalComposeAccessory { self.router.composeNewEntry() }
        }
        .fullScreenCover(item: $router.composition, content: compose(for:))
        .task { await viewModel.load() }
    }

    /// 큰 제목 아래 한 줄 — 지금 목록이 무엇을 보여 주고 있는지 (디자인 문서 §4.0).
    /// 하단 액세서리에서 올라왔다. 목록의 범위를 말하는 문장이라 제목 옆이 제자리고,
    /// 화면 반대쪽 끝에 있으면 제목과 눈이 두 번 오간다.
    ///
    /// 아직 못 읽었거나 한 건도 없으면 빈 문자열이라 줄 자체가 그려지지 않는다 — 빈 상태는
    /// 목록 자리의 `EmptyStateView` 가 이미 같은 말을 하고 있어 두 번 할 필요가 없다.
    private var subtitleText: String {
        switch viewModel.caption {
        case .none, .empty:
            ""
        case let .filtered(name, count):
            "\(name) \(countText(count))"
        case let .thisMonth(count):
            "\(Constants.thisMonthPrefix) \(countText(count))"
        case let .total(count):
            "\(Constants.totalPrefix) \(countText(count))"
        }
    }

    /// 종목 필터는 "지금 목록이 어떤 상태인가" 를 말하므로 왼쪽에 둔다 — 오른쪽 검색은
    /// 새로 무언가를 찾는 컨트롤이라 성격이 다르다 (포트폴리오 탭 정렬 메뉴와 같은 자리).
    ///
    /// 태그로 쓸 종목이 하나도 없으면 메뉴를 달지 않는다. 고를 게 "전체" 뿐인 필터는
    /// 눌러도 아무것도 바꾸지 못한다.
    @ToolbarContentBuilder
    private var holdingFilterItem: some ToolbarContent {
        if let holdings = viewModel.holdingTagsState.value, !holdings.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker(Constants.filterTitle, selection: holdingFilter) {
                        Text(Constants.allHoldingsTitle)
                            .tag(UUID?.none)

                        ForEach(holdings) { holding in
                            Text(holding.name)
                                .tag(UUID?.some(holding.id))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(Constants.filterTitle, systemImage: filterSymbolName)
                }
                // 아이콘은 "걸러져 있다" 까지만 말한다. 무엇으로 걸렀는지는 메뉴를 열어야
                // 보이므로, 음성으로는 고른 종목 이름을 직접 읽어 준다.
                .accessibilityValue(viewModel.selectedHoldingName ?? Constants.allHoldingsTitle)
            }
        }
    }

    /// 필터가 걸리면 채운 아이콘으로 바꾼다 — 칩 줄이 사라진 뒤로는 이 아이콘이 "목록이
    /// 전부가 아니다" 를 화면에서 말하는 유일한 자리다.
    private var filterSymbolName: String {
        viewModel.selectedHoldingID == nil
            ? Constants.filterSymbolName
            : Constants.activeFilterSymbolName
    }

    /// `selectedHoldingID` 를 직접 묶지 않는 이유는 필터가 바뀌면 목록을 다시 읽어야 하기
    /// 때문이다. 그 판단을 ViewModel 이 들고 있어야 화면 밖에서도 같은 동작이 재현된다.
    private var holdingFilter: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedHoldingID },
            set: { holdingID in Task { await viewModel.selectHolding(holdingID) } }
        )
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
                    tags: tags(for: entry)
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
        // 시안 §6.4 의 콘텐츠 열 상단 여백 8. `padding` 이 아니라 safe area 를 넓히는 쪽이라
        // 첫 셀은 띄우면서도 스크롤은 그대로 네비게이션 바 밑을 지난다.
        .safeAreaPadding(.top, .spacingS)
        // 액세서리 캡슐이 마지막 셀을 가리지 않도록 하단을 띄운다 (UI 스펙 §3.1).
        .safeAreaPadding(.bottom, .spacingXL)
    }

    // MARK: - Function

    /// `.noEntry` 만 CTA 를 비운다 — 하단 액세서리 캡슐 전체가 작성 버튼이라 여기 버튼을 더
    /// 두면 같은 동작이 한 화면에 둘이 된다. 캡슐이 축약돼도 라벨이 "작성" 으로 줄 뿐 사라지지
    /// 않으므로 다음 행동은 화면에 남는다.
    ///
    /// `.noMatch` 는 반대다. 무엇이 걸러냈는지가 툴바 아이콘과 접힌 검색창에만 남아 있어,
    /// 되돌릴 버튼이 없으면 목록이 텅 빈 채로 갇힌다.
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
                message: Constants.noMatchMessage,
                actionTitle: Constants.clearFiltersTitle
            ) {
                Task { await viewModel.clearFilters() }
            }
        }
    }

    private func countText(_ count: Int) -> String {
        "\(count)\(Constants.countUnit)"
    }

    /// 종목을 캡슐이 읽을 수 있는 표시용 값으로 옮긴다. 분류를 같이 실어 보내야 캡슐이
    /// 분류색 유리를 입는다 — 이름만 넘기면 태그가 전부 같은 색이 된다.
    private func tags(for entry: JournalRecord) -> [JournalTag] {
        viewModel.taggedHoldings(for: entry).map { holding in
            JournalTag(id: holding.id, name: holding.name, category: holding.category)
        }
    }

    private func detail(for route: JournalRoute) -> some View {
        switch route {
        case let .detail(record):
            JournalDetailView(
                record: record,
                tags: tags(for: record),
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
            draftContent: container.resolve((any DraftJournalContentUseCaseProtocol).self),
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
    static let filterTitle = "종목 필터"
    static let filterSymbolName = "line.3.horizontal.decrease.circle"
    static let activeFilterSymbolName = "line.3.horizontal.decrease.circle.fill"
    static let allHoldingsTitle = "전체"

    static let thisMonthPrefix = "이번 달"
    static let totalPrefix = "전체"
    static let countUnit = "건"

    static let emptySymbolName = "book.closed"
    static let emptyTitle = "첫 매매일지를 남겨보세요"
    static let emptyMessage = "왜 샀는지 적어두면 다음 판단이 쉬워집니다."

    static let noMatchSymbolName = "magnifyingglass"
    static let noMatchTitle = "조건에 맞는 일지가 없어요"
    static let noMatchMessage = "검색어나 종목 필터를 바꿔보세요."
    static let clearFiltersTitle = "검색·필터 해제"

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
