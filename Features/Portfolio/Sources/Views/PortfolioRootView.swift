//
//  PortfolioRootView.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// 포트폴리오 탭 루트 (PF-1 ~ PF-6). 탭 전용 `NavigationStack` 과 라우터를 여기서만 만든다.
public struct PortfolioRootView: View {

    // MARK: - Property

    @Environment(DIContainer.self) private var container
    @Environment(ErrorHandler.self) private var errorHandler

    @State private var router = PortfolioRouter()

    // MARK: - Body

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            PortfolioListView(container: container, errorHandler: errorHandler)
                .navigationDestination(for: PortfolioRoute.self) { route in
                    destination(for: route)
                }
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.portfolio) {
            PortfolioActionAccessory(
                onAddHolding: { router.presentHoldingEditor(.create) },
                onShowCashFlow: { router.showCashFlowList() }
            )
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
