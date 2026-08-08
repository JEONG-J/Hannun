//
//  AppRouter.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import Observation
import SwiftUI

/// 모듈 간 전환·딥링크 조율자. Feature 내부 화면 전환은 각 Feature Router 가 맡는다.
///
/// Feature 는 이 타입을 모르고 `AppRouting` 만 본다 — 앱 타깃은 Feature 를 의존하므로
/// 반대 방향 참조가 생기면 순환이 된다.
@MainActor
@Observable
final class AppRouter: AppRouting {
    // MARK: - Property

    var selectedTab: AppTab = .netWorth
    private(set) var pendingRoute: AppRoute?

    /// 설정 시트 표시 여부. 시트를 닫는 쪽은 SwiftUI 라 바인딩으로 열어 둔다.
    var isPresentingSettings = false

    // MARK: - Function

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func navigate(to route: AppRoute) {
        pendingRoute = route
        selectedTab = route.tab
    }

    func presentSettings() {
        isPresentingSettings = true
    }

    func consumeRoute(for tab: AppTab) -> AppRoute? {
        guard let pendingRoute, pendingRoute.tab == tab else { return nil }

        self.pendingRoute = nil
        return pendingRoute
    }
}
