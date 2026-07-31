//
//  AssetCategoryStyle.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// DesignSystem 이 Domain 없이 분류를 렌더링할 수 있는 이유 — AssetCategory 가 Core 에 있기 때문이다.
public extension AssetCategory {
    /// 도넛 섹터·리스트 dot·소계가 모두 이 프로퍼티를 거치게 해서 색이 갈리지 않게 한다
    /// — 리스트가 곧 범례다.
    var color: Color {
        switch self {
        case .cash: .categoryCash
        case .domesticStock: .categoryDomestic
        case .overseasStock: .categoryForeign
        case .etf: .categoryEtf
        case .crypto: .categoryCrypto
        }
    }

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
