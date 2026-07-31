import HannunCore
import SwiftUI

/// DesignSystem 이 Domain 없이 분류를 렌더링할 수 있는 이유 — AssetCategory 가 Core 에 있기 때문 (§3).
public extension AssetCategory {
    var systemImageName: String {
        switch self {
        case .cash: "wonsign.circle"
        case .domesticStock: "chart.line.uptrend.xyaxis"
        case .overseasStock: "globe.americas"
        case .etf: "square.stack.3d.up"
        case .crypto: "bitcoinsign.circle"
        }
    }
}
