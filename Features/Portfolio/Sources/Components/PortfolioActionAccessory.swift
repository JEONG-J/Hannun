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

    @Environment(\.accessoryLayout) private var layout

    let onAddHolding: () -> Void
    let onShowCashFlow: () -> Void

    // MARK: - Body

    var body: some View {
        BottomAccessory {
            if collapsesToMenu {
                overflowMenu
            } else {
                AccessoryActionButton(
                    Constants.cashFlowTitle,
                    systemImageName: Constants.cashFlowSymbolName,
                    style: .secondary,
                    action: onShowCashFlow
                )
            }
        } trailing: {
            // 생성 액션은 항상 trailing — 4탭 공통 문법이다. 축약에서는 아이콘 원형으로 줄인다.
            if collapsesToMenu {
                AccessoryActionButton(
                    systemImageName: Constants.addHoldingSymbolName,
                    accessibilityLabel: Constants.addHoldingTitle,
                    action: onAddHolding
                )
            } else {
                AccessoryActionButton(
                    Constants.addHoldingTitle,
                    systemImageName: Constants.addHoldingSymbolName,
                    action: onAddHolding
                )
            }
        }
    }

    // MARK: - Function

    /// 탭바가 최소화되면 캡슐이 한 줄로 줄어 라벨 두 개가 다 들어가지 않는다.
    ///
    /// 넘치는 액션을 툴바로 내보내지 않고 액세서리 **안에서** Menu 로 접는다 — 이 캡슐이
    /// 두 액션의 유일한 진입점이라는 §3.1 결정을 되돌리지 않기 위해서다.
    /// 성과 탭 벤치마크 칩이 접히는 것과 같은 규칙이다.
    private var collapsesToMenu: Bool { layout == .inline }

    private var overflowMenu: some View {
        Menu {
            Button(action: onShowCashFlow) {
                Label(Constants.cashFlowTitle, systemImage: Constants.cashFlowSymbolName)
            }
        } label: {
            menuLabel
        }
        .accessibilityLabel(Constants.overflowAccessibilityLabel)
    }

    /// 유일 진입점이라 시각적 바닥은 유지하되, 불투명 슬래브 대신 저채도 wash 를 쓴다 —
    /// 주요 액션의 brand 채움과 겹치지 않는 One Fill Rule 안의 절충이다.
    /// [게이트 대기 G5] 3초 내 발견 실패 시 `surfaceSecondary` 로 되돌린다.
    private var menuLabel: some View {
        Image(systemName: Constants.overflowSymbolName)
            .hannunFont(.rowTitle)
            .foregroundStyle(Color.textSecondary)
            .frame(width: .minimumTouchTarget, height: .minimumTouchTarget)
            .background(HannunTint.neutralTint, in: .circle)
    }
}

fileprivate enum Constants {
    static let addHoldingTitle = "종목 추가"
    static let addHoldingSymbolName = "plus"
    static let cashFlowTitle = "입출금 기록"
    static let cashFlowSymbolName = "arrow.left.arrow.right"
    static let overflowSymbolName = "ellipsis"
    static let overflowAccessibilityLabel = "추가 작업"
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

#Preview("포트폴리오 액세서리 · 축약") {
    PortfolioActionAccessory(onAddHolding: {}, onShowCashFlow: {})
        .accessoryLayout(.inline)
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
