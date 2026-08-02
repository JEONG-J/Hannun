//
//  JournalComposeAccessory.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import SwiftUI

/// 매매일지 탭의 하단 액세서리. FAB 를 대체하는 작성 진입점이다 (JR-2).
///
/// 좌측 힌트 문구는 장식이 아니라 빈 상태의 CTA 역할을 겸한다 — 그래서
/// 목록이 비어 있어도 `EmptyStateView` 쪽에 버튼을 따로 두지 않는다.
struct JournalComposeAccessory: View {
    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let action: () -> Void

    // MARK: - Body

    var body: some View {
        BottomAccessory {
            AccessoryCaption(hintText)
        } trailing: {
            // 생성 = 우측 brand 라벨 캡슐 — 포트폴리오와 같은 문법이다. 축약에서는
            // 아이콘 원형으로 줄이되 VoiceOver 라벨은 같은 의미를 유지한다.
            if layout == .inline {
                AccessoryActionButton(
                    systemImageName: Constants.composeSymbolName,
                    accessibilityLabel: Constants.composeAccessibilityLabel,
                    action: action
                )
            } else {
                AccessoryActionButton(
                    Constants.composeTitle,
                    systemImageName: Constants.composeSymbolName,
                    action: action
                )
            }
        }
    }

    /// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 힌트는 빈 상태의 CTA 라
    /// 숨기는 대신 줄인다.
    private var hintText: String {
        layout == .inline || dynamicTypeSize.isAccessibilitySize
            ? Constants.inlineHintText
            : Constants.hintText
    }
}

fileprivate enum Constants {
    static let hintText = "오늘의 매매를 기록해보세요"
    static let inlineHintText = "매매 기록"
    static let composeSymbolName = "pencil.line"
    static let composeTitle = "작성"
    static let composeAccessibilityLabel = "일지 작성"
}

#if DEBUG
#Preview("일지 작성 액세서리 · 라이트") {
    JournalComposeAccessory {}
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("일지 작성 액세서리 · 다크") {
    JournalComposeAccessory {}
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}

#Preview("일지 작성 액세서리 · 축약") {
    JournalComposeAccessory {}
        .accessoryLayout(.inline)
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
