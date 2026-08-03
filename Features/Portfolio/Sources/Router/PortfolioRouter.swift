//
//  PortfolioRouter.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Observation

/// 포트폴리오 탭 전용 라우터. 탭 밖으로 나가는 이동은 `AppRouter` 가 맡는다.
///
/// 탭 안에는 push 로 열리는 화면이 없어 `NavigationStack` path 를 들지 않는다. 종목 목록과
/// 입출금 기록은 `route` 를 뒤집어 루트째 갈아 끼운다 — 자세한 이유는 `PortfolioRoute` 참고.
///
/// sheet 슬롯을 종목용·입출금용으로 나눠 둔 이유는, 입출금 목록에서 두 sheet 가 동시에
/// 후보가 되는 순간이 있어서다. 하나로 합치면 `sheet(item:)` 이 서로를 덮어쓴다.
@MainActor
@Observable
final class PortfolioRouter {

    // MARK: - Property

    /// 탭 루트에 지금 걸려 있는 면. 스택이 아니라 값 하나라 연타해도 겹쳐 쌓이지 않는다.
    var route: PortfolioRoute = .holdings
    var holdingEditor: HoldingEditorMode?
    var cashFlowEditor: CashFlowEditorMode?

    // MARK: - Function

    func toggleRoute() {
        route = route.counterpart
    }

    func presentHoldingEditor(_ mode: HoldingEditorMode) {
        holdingEditor = mode
    }

    func presentCashFlowEditor(_ mode: CashFlowEditorMode) {
        cashFlowEditor = mode
    }
}
