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

    let action: () -> Void

    // MARK: - Body

    var body: some View {
        BottomAccessory {
            Label(Constants.hintText, systemImage: Constants.hintSymbolName)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .padding(.leading, .spacingS)

            Spacer(minLength: .spacingS)

            AccessoryActionButton(systemImageName: Constants.composeSymbolName, action: action)
        }
        .padding(.horizontal, .spacingL)
        .padding(.bottom, .spacingS)
    }
}

fileprivate enum Constants {
    static let hintText = "오늘의 매매를 기록해보세요"
    static let hintSymbolName = "sparkles"
    static let composeSymbolName = "pencil.line"
}

#if DEBUG
#Preview("일지 작성 액세서리 · 라이트") {
    JournalComposeAccessory {}
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("일지 작성 액세서리 · 다크") {
    JournalComposeAccessory {}
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
