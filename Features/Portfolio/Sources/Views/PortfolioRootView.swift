import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 포트폴리오 탭 루트. 기능 명세 PF-1~6 는 여기부터 구현한다.
public struct PortfolioRootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView("포트폴리오", systemImage: "square.dashed")
                .navigationTitle("포트폴리오")
        }
    }
}
