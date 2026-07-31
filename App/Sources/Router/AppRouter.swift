//
//  AppRouter.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import Observation
import SwiftUI

/// 탭 식별자. 딥링크가 지정하는 진입 탭도 이 값으로 표현한다.
enum AppTab: String, Hashable, CaseIterable {
    case netWorth
    case portfolio
    case performance
    case journal
}

/// 모듈 간 전환·딥링크 조율자. Feature 내부 화면 전환은 각 Feature Router 가 맡는다.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .netWorth

    func select(_ tab: AppTab) {
        selectedTab = tab
    }
}
