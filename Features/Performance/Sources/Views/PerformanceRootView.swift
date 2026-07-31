//
//  PerformanceRootView.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 투자 성과 탭 루트. 기능 명세 PM-1~4 는 여기부터 구현한다.
public struct PerformanceRootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView("투자 성과", systemImage: "square.dashed")
                .navigationTitle("투자 성과")
        }
    }
}
