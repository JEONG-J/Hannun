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
        NavigationStack {
            routedScreen
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        // 등록 클로저가 `NavigationStack` 바깥에서 실행돼도 화면이 바뀌는 이유는, 어떤 면을
        // 걸지 들고 있는 라우터를 여기서 참조로 붙잡기 때문이다.
        .tabAccessory(.portfolio) {
            PortfolioActionAccessory(viewModel: self.viewModel, router: self.router)
        }
        .environment(router)
    }

    // MARK: - Function

    /// 스택에 쌓지 않고 루트를 통째로 바꾼다. 두 화면이 각자 `navigationTitle` 과 툴바를
    /// 들고 있어, 바뀌는 순간 상단이 함께 갈리는 것으로 "면이 넘어갔다"는 신호가 나온다.
    ///
    /// 입출금 기록은 이때마다 다시 만들어져 `task` 가 새로 돈다. 이 탭에 머무는 내내 살려
    /// 둘 만큼 무거운 화면이 아니고, 오히려 종목을 손보고 돌아왔을 때 목록이 갱신돼 있는
    /// 편이 맞다. 반대로 종목 목록의 검색어·정렬·필터는 탭 루트가 쥔 ViewModel 에 있어
    /// 화면이 새로 만들어져도 그대로다.
    @ViewBuilder
    private var routedScreen: some View {
        switch router.route {
        case .holdings:
            PortfolioListView(
                viewModel: viewModel,
                container: container,
                errorHandler: errorHandler
            )
        case .cashFlow:
            CashFlowListView(container: container, errorHandler: errorHandler)
        }
    }
}
