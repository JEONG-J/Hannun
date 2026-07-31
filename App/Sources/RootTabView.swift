//
//  RootTabView.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import JournalFeature
import NetWorthFeature
import PerformanceFeature
import PortfolioFeature
import SwiftUI

/// 4개 탭 구성. 탭별 NavigationStack 은 각 Feature 루트 View 가 소유한다.
struct RootTabView: View {
    // MARK: - Property

    @Environment(AppRouter.self) private var router
    @Environment(\.tabAccessoryHost) private var accessoryHost

    // MARK: - Body

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("순자산", systemImage: "wonsign.circle", value: AppTab.netWorth) {
                NetWorthRootView()
            }
            Tab("포트폴리오", systemImage: "chart.pie", value: AppTab.portfolio) {
                PortfolioRootView()
            }
            Tab("성과", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.performance) {
                PerformanceRootView()
            }
            Tab("매매일지", systemImage: "book.pages", value: AppTab.journal) {
                JournalRootView()
            }
        }
        // 액세서리는 TabView 에 하나만 붙고 내용은 선택된 탭으로 분기한다 (UI 스펙 §3.1).
        // 실체는 각 Feature 가 `.tabAccessory(_:)` 로 등록한다 — 액세서리가 그 탭의
        // 화면 상태(통화·벤치마크 선택)를 읽어야 하므로 여기서 만들 수 없다.
        .tabViewBottomAccessory {
            accessoryHost?.content(for: router.selectedTab)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
