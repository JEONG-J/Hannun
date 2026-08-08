//
//  StaleBadge.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 시세 갱신 실패 배지. 화면을 비우는 대신 마지막 캐시값을 그대로 두고 이 배지로 신선도를 알린다.
///
/// 경고인데도 `gain`(빨강)은 물론 `warning`(앰버)도 쓰지 않는다. 손익 색은 금액 옆에서 상승과
/// 혼동되고, `warning` 은 사용자가 지금 고쳐야 할 자리에만 쓴다 — 시세 신선도는 고칠 수 없는
/// 주변 정보라 중립 tint + 경고 아이콘으로 조용히 알린다.
public struct StaleBadge: View {

    // MARK: - Property

    private let message: String
    private let action: (() -> Void)?

    // MARK: - Body

    public init(minutesElapsed: Int) {
        message = "\(Constants.failurePrefix) \(minutesElapsed)분 전 기준"
        action = nil
    }

    /// 갱신 시각을 분 단위로 환산할 수 없을 때(예: "어제 종가 기준") 문구를 직접 넣는다.
    ///
    /// - Parameter action: 사용자가 지금 손댈 수 있는 원인일 때만 넣는다(앱키 미설정 등).
    ///   갱신 실패 대부분은 사용자가 고칠 수 없어 기본은 알리기만 하는 배지다.
    public init(message: String, action: (() -> Void)? = nil) {
        self.message = message
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { badge }
                .buttonStyle(.plain)
        } else {
            badge
        }
    }

    private var badge: some View {
        HStack(spacing: .spacingXS) {
            Image(systemName: Constants.warningSymbolName)
                .imageScale(.small)

            Text(message)
                .hannunFont(.caption, tabularFigures: true)

            if action != nil {
                Image(systemName: Constants.disclosureSymbolName)
                    .imageScale(.small)
            }
        }
        .foregroundStyle(Color.textSecondary)
        // 누를 수 있는 배지는 문구가 이유를 다 말해야 해서 한 줄에 가두지 않는다.
        .lineLimit(action == nil ? 1 : nil)
        .multilineTextAlignment(.leading)
        .padding(.vertical, .spacingXS)
        .padding(.horizontal, .spacingS)
        .background(HannunTint.neutralTint, in: .rect(cornerRadius: .radiusS))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

fileprivate enum Constants {
    static let failurePrefix = "갱신 실패 ·"
    static let warningSymbolName = "exclamationmark.triangle.fill"
    static let disclosureSymbolName = "chevron.right"
}

#if DEBUG
private struct StaleBadgePreview: View {

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            StaleBadge(minutesElapsed: 7)
            StaleBadge(minutesElapsed: 128)
            StaleBadge(message: "갱신 실패 · 어제 종가 기준")
            StaleBadge(message: "시세 앱키가 없어 주식·ETF 시세가 비어 있어요") {}
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }
}

#Preview("갱신 실패 배지 · 라이트") {
    StaleBadgePreview()
        .preferredColorScheme(.light)
}

#Preview("갱신 실패 배지 · 다크") {
    StaleBadgePreview()
        .preferredColorScheme(.dark)
}
#endif
