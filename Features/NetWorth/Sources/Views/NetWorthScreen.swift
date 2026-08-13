//
//  NetWorthScreen.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import SwiftUI

/// 순자산 본문. 총자산(NW-1) → 비중 도넛(NW-3) → 카테고리 소계(NW-4) 순으로 쌓고,
/// 기준 통화 토글(NW-2)은 하단 액세서리가 맡는다.
struct NetWorthScreen: View {

    // MARK: - Property

    @Environment(\.appRouter) private var appRouter

    @State private var viewModel: NetWorthViewModel

    // MARK: - Body

    @MainActor
    init(container: DIContainer) {
        _viewModel = State(initialValue: NetWorthViewModel(container: container))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, .spacingL)
                    .padding(.top, .spacingXS)
            }
            // 빈 상태 한 덩어리만 남는 화면에서는 가운데로 세운다. 목록·스켈레톤처럼 뷰포트를
            // 채우는 내용에는 영향이 없다 — `.alignment` 는 내용이 더 짧을 때만 쓰인다.
            .defaultScrollAnchor(scrollAlignment, for: .alignment)
            .background(Color.backgroundPrimary)
            // 시세 수동 갱신 경로. 액세서리 캡션은 정적이므로 이게 유일한 갱신 수단이다 (NW-2).
            .refreshable { await viewModel.load() }
            .navigationTitle(Constants.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { settingsToolbarItem }
            // 액세서리 캡슐이 마지막 카드를 가리지 않도록 하단을 띄운다 (UI 스펙 §3.1).
            .safeAreaPadding(.bottom, .spacingXL)
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.netWorth) {
            NetWorthAccessory(viewModel: self.viewModel)
        }
        .task(id: viewModel.baseCurrency) {
            await viewModel.load()
        }
    }

    /// 설정으로 가는 상설 입구.
    ///
    /// 네 탭 중 여기에 두는 이유는 이 툴바만 비어 있어서가 아니라, **보유가 0건일 때도 그대로
    /// 있는 유일한 자리**라서다. 시세 앱키를 넣어야 하는 시점은 대개 아무것도 없는 첫 화면인데,
    /// 포트폴리오 툴바의 컨트롤은 목록이 비면 함께 사라진다.
    @ToolbarContentBuilder
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(Constants.settingsTitle, systemImage: Constants.settingsSymbolName) {
                appRouter?.presentSettings()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.summary {
        case .idle, .loading:
            skeleton

        case let .loaded(summary) where summary.isEmpty:
            empty

        case let .loaded(summary):
            loaded(summary)

        case let .failed(error):
            failure(error)
        }
    }

    /// 스크롤 내용이 빈 상태 하나뿐이라 위에서부터 쌓을 이유가 없는 화면.
    private var scrollAlignment: UnitPoint {
        switch viewModel.summary {
        case let .loaded(summary):
            summary.isEmpty ? .center : .top
        case .failed:
            .center
        case .idle, .loading:
            .top
        }
    }

    /// 첫 로딩에만 보인다 — 갱신 중에는 이전 값을 그대로 두므로 여기로 오지 않는다.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            TotalAssetBlock(total: Money(amount: 0, currency: viewModel.baseCurrency), change: nil)

            ConcentricRectangle.hannunContainer()
                .fill(Color.surfacePrimary)
                .frame(height: Constants.skeletonSurfaceHeight)
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel(Constants.skeletonAccessibilityLabel)
    }

    /// 보유가 0건이면 히어로를 접는다. `₩0` + 변동 없음은 바로 아래 "첫 자산을 추가해 보세요"
    /// 와 같은 말이라, 화면에서 가장 큰 숫자 자리를 빈 값에 내주면 안내가 묻힌다.
    /// 총자산을 말할 자리는 액세서리가 그대로 들고 있다 (히어로가 없으니 교대도 없다).
    ///
    /// CTA 는 두지 않는다 — 등록은 이 탭이 아니라 포트폴리오에서 한다. 버튼을 누르면 탭을
    /// 옮겨 놓고 거기서 다시 오른쪽 위 `+` 를 찾게 만드는 두 번 걸음이라, 갈 곳만 알린다.
    private var empty: some View {
        EmptyStateView(
            systemImageName: Constants.emptySymbolName,
            title: Constants.emptyTitle,
            message: Constants.emptyMessage
        )
        // 히어로가 사라지면 교대 신호도 멈춘다 — 마지막으로 내려간 값이 남아 있으면
        // 액세서리가 계속 `₩0` 을 말한다.
        .onAppear { viewModel.isHeroVisible = true }
    }

    private func loaded(_ summary: NetWorthSummary) -> some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            TotalAssetBlock(total: summary.total, change: summary.dailyChange)
                // 히어로가 밀려 나가면 액세서리가 총자산을 대신 말한다 (디자인 문서 §6).
                .onScrollVisibilityChange(threshold: Constants.heroVisibilityThreshold) {
                    viewModel.isHeroVisible = $0
                }

            AllocationCard(
                rows: summary.subtotalRows,
                selection: $viewModel.selectedCategory
            ) { category in
                appRouter?.navigate(to: .portfolio(category: category))
            }
        }
        .hannunAnimation(.standard, value: summary)
    }

    private func failure(_ error: AppError) -> some View {
        EmptyStateView(
            systemImageName: Constants.failureSymbolName,
            title: Constants.failureTitle,
            message: error.userMessage,
            actionTitle: Constants.retryActionTitle
        ) {
            Task { await viewModel.load() }
        }
    }
}

fileprivate enum Constants {
    static let navigationTitle = "순자산"

    static let settingsTitle = "설정"
    static let settingsSymbolName = "gearshape"

    /// 히어로가 이만큼도 안 남으면 "사라졌다"로 본다. 절반으로 잡으면 총자산 숫자가 반쯤
    /// 잘려 보이는 구간에서 액세서리가 먼저 바뀌어 두 값이 겹쳐 읽힌다.
    static let heroVisibilityThreshold: Double = 0.1

    static let skeletonSurfaceHeight: CGFloat = 360
    static let skeletonAccessibilityLabel = "순자산 불러오는 중"

    static let emptySymbolName = "tray"
    static let emptyTitle = "첫 자산을 추가해 보세요"
    /// 등록하는 자리를 짚어 준다 — 이 탭에는 추가 경로가 없다.
    static let emptyMessage = "포트폴리오 탭에서 종목을 등록하면 자산군별 비중을 볼 수 있어요."

    static let failureSymbolName = "exclamationmark.triangle"
    static let failureTitle = "순자산을 불러오지 못했어요"
    static let retryActionTitle = "다시 시도"
}
