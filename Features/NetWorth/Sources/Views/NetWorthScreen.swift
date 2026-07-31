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
            .background(Color.backgroundPrimary)
            .navigationTitle(Constants.navigationTitle)
            // 액세서리 캡슐이 마지막 카드를 가리지 않도록 하단을 띄운다 (UI 스펙 §3.1).
            .safeAreaPadding(.bottom, .spacingXL)
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.netWorth) {
            NetWorthAccessory(
                freshness: viewModel.freshness,
                baseCurrency: $viewModel.baseCurrency
            )
        }
        .task(id: viewModel.baseCurrency) {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.summary {
        case .idle, .loading:
            skeleton

        case let .loaded(summary):
            loaded(summary)

        case let .failed(error):
            failure(error)
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

    private func loaded(_ summary: NetWorthSummary) -> some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            TotalAssetBlock(total: summary.total, change: summary.dailyChange)

            if summary.isEmpty {
                EmptyStateView(
                    systemImageName: Constants.emptySymbolName,
                    title: Constants.emptyTitle,
                    message: Constants.emptyMessage,
                    actionTitle: Constants.emptyActionTitle
                ) {
                    appRouter?.navigate(to: .portfolio(category: nil))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacingXXL)
            } else {
                AllocationCard(
                    breakdown: summary.fundedBreakdown,
                    total: summary.total,
                    selection: $viewModel.selectedCategory
                ) { category in
                    appRouter?.navigate(to: .portfolio(category: category))
                }
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacingXXL)
    }
}

fileprivate enum Constants {
    static let navigationTitle = "순자산"

    static let skeletonSurfaceHeight: CGFloat = 360
    static let skeletonAccessibilityLabel = "순자산 불러오는 중"

    static let emptySymbolName = "tray"
    static let emptyTitle = "첫 자산을 추가해 보세요"
    static let emptyMessage = "보유 종목을 등록하면 자산군별 비중을 볼 수 있어요."
    static let emptyActionTitle = "종목 추가"

    static let failureSymbolName = "exclamationmark.triangle"
    static let failureTitle = "순자산을 불러오지 못했어요"
    static let retryActionTitle = "다시 시도"
}
