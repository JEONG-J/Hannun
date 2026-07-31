import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 순자산 탭 루트. 기능 명세 NW-1~4 는 여기부터 구현한다.
public struct NetWorthRootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView("순자산", systemImage: "square.dashed")
                .navigationTitle("순자산")
        }
    }
}
