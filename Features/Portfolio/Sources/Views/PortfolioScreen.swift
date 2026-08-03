//
//  PortfolioScreen.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunCore
import HannunDomain
import SwiftUI

/// 포트폴리오 탭의 실질 루트. 탭 전용 `NavigationStack`·라우터·목록 ViewModel 을 여기서 만든다.
///
/// 목록 ViewModel 을 화면이 아니라 **탭 루트**가 소유하는 이유는 하단 액세서리 때문이다.
/// 액세서리는 탭에 속해 루트에만 등록되는데(UI 스펙 §3.1) 왼쪽 한 줄이 말할 내용(종목 수·
/// 기준 시각)은 목록의 상태다. 목록이 ViewModel 을 들고 있으면 액세서리가 닿을 방법이 없다.
struct PortfolioScreen: View {

    // MARK: - Property

    @State private var router = PortfolioRouter()
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
        NavigationStack(path: $router.path) {
            PortfolioListView(
                viewModel: viewModel,
                container: container,
                errorHandler: errorHandler
            )
            .navigationDestination(for: PortfolioRoute.self) { route in
                destination(for: route)
            }
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.portfolio) {
            PortfolioActionAccessory(viewModel: self.viewModel) {
                self.router.presentHoldingEditor(.create)
            }
        }
        .environment(router)
    }

    // MARK: - Function

    @ViewBuilder
    private func destination(for route: PortfolioRoute) -> some View {
        switch route {
        case .cashFlowList:
            CashFlowListView(container: container, errorHandler: errorHandler)
        }
    }
}
