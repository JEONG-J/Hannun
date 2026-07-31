//
//  PortfolioRouter.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Observation

/// 포트폴리오 탭 전용 라우터. 탭 밖으로 나가는 이동은 `AppRouter` 가 맡는다.
///
/// sheet 슬롯을 종목용·입출금용으로 나눠 둔 이유는, 입출금 목록에서 두 sheet 가 동시에
/// 후보가 되는 순간이 있어서다. 하나로 합치면 `sheet(item:)` 이 서로를 덮어쓴다.
@MainActor
@Observable
final class PortfolioRouter {

    // MARK: - Property

    var path: [PortfolioRoute] = []
    var holdingEditor: HoldingEditorMode?
    var cashFlowEditor: CashFlowEditorMode?

    // MARK: - Function

    func showCashFlowList() {
        path.append(.cashFlowList)
    }

    func presentHoldingEditor(_ mode: HoldingEditorMode) {
        holdingEditor = mode
    }

    func presentCashFlowEditor(_ mode: CashFlowEditorMode) {
        cashFlowEditor = mode
    }
}
