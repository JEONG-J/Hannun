//
//  PortfolioActionAccessory.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import SwiftUI

/// 포트폴리오 탭의 하단 액세서리 — 생성 액션 2개 (PF-2, PF-5/6).
///
/// 툴바에 같은 액션을 겹쳐 두지 않는다. 이 캡슐이 두 액션의 유일한 진입점이다 (UI 스펙 §3.1).
struct PortfolioActionAccessory: View {

    // MARK: - Property

    let onAddHolding: () -> Void
    let onShowCashFlow: () -> Void

    // MARK: - Body

    var body: some View {
        BottomAccessory {
            AccessoryActionButton(
                Constants.addHoldingTitle,
                systemImageName: Constants.addHoldingSymbolName,
                action: onAddHolding
            )

            Spacer(minLength: .spacingS)

            AccessoryActionButton(
                Constants.cashFlowTitle,
                systemImageName: Constants.cashFlowSymbolName,
                style: .secondary,
                action: onShowCashFlow
            )
        }
    }
}

fileprivate enum Constants {
    static let addHoldingTitle = "종목 추가"
    static let addHoldingSymbolName = "plus"
    static let cashFlowTitle = "입출금 기록"
    static let cashFlowSymbolName = "arrow.left.arrow.right"
}

#if DEBUG
#Preview("포트폴리오 액세서리 · 라이트") {
    PortfolioActionAccessory(onAddHolding: {}, onShowCashFlow: {})
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("포트폴리오 액세서리 · 다크") {
    PortfolioActionAccessory(onAddHolding: {}, onShowCashFlow: {})
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
