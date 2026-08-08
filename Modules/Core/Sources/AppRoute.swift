//
//  AppRoute.swift
//  HannunCore
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 탭 식별자. 딥링크가 지정하는 진입 탭도 이 값으로 표현한다.
public enum AppTab: String, Hashable, CaseIterable, Sendable {
    case netWorth
    case portfolio
    case performance
    case journal
}

/// 탭 경계를 넘는 이동 요청.
///
/// Feature 끼리 직접 의존하면 순환이 생기므로(`NetWorthFeature` → `PortfolioFeature` 금지),
/// 목적지를 값으로만 표현해 공유 커널에 둔다. 실체 라우터는 앱 타깃이 갖는다.
public enum AppRoute: Hashable, Sendable {
    /// 포트폴리오 탭. `category` 가 있으면 해당 카테고리로 필터링한 상태로 연다 (NW-4).
    case portfolio(category: AssetCategory?)

    /// 이 요청이 도착해야 할 탭.
    public var tab: AppTab {
        switch self {
        case .portfolio: .portfolio
        }
    }
}

/// 탭 전환·딥링크 조율자가 Feature 에 노출하는 표면.
///
/// 보내는 쪽은 `navigate(to:)` 만 알면 되고, 받는 쪽은 자기 탭으로 온 요청을
/// `consumeRoute(for:)` 로 꺼낸다. 꺼낸 요청은 사라지므로 탭을 다시 눌러도 재적용되지 않는다.
@MainActor
public protocol AppRouting: AnyObject {
    /// 현재 선택된 탭.
    var selectedTab: AppTab { get set }
    /// 아직 소비되지 않은 이동 요청.
    var pendingRoute: AppRoute? { get }

    /// 요청의 목적지 탭으로 전환하고 요청을 대기열에 넣는다.
    func navigate(to route: AppRoute)
    /// 해당 탭으로 온 요청이 있으면 꺼내고 대기열을 비운다.
    func consumeRoute(for tab: AppTab) -> AppRoute?

    /// 설정 화면을 띄운다.
    ///
    /// `AppRoute` 로 표현하지 않는 이유는 목적지 탭이 없기 때문이다 — 설정은 탭 위에 덮이는
    /// 시트라 어느 탭에서 불러도 같은 자리에 뜬다. 시세 앱키가 필요한 자리가 세 탭에 흩어져
    /// 있어 부르는 쪽이 여럿이다.
    func presentSettings()
}

public extension EnvironmentValues {
    /// 앱 타깃이 주입하는 조율자. 프리뷰처럼 앱 셸이 없는 환경에서는 nil 이다.
    @Entry var appRouter: (any AppRouting)?
}
