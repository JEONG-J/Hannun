import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 매매일지 탭 루트. 기능 명세 JR-1~4 는 여기부터 구현한다.
public struct JournalRootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView("매매일지", systemImage: "square.dashed")
                .navigationTitle("매매일지")
        }
    }
}
