//
//  RootTabView.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import JournalFeature
import NetWorthFeature
import PerformanceFeature
import PortfolioFeature
import SwiftUI

/// 4개 탭 구성. 탭별 NavigationStack 은 각 Feature 루트 View 가 소유한다.
struct RootTabView: View {
    @Environment(AppRouter.self) private var router

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
    }
}
