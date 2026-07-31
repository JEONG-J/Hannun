//
//  EmptyStateView.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 빈 상태 안내. 빈 화면을 방치하지 않고 다음 행동을 제시한다.
///
/// CTA 는 생략할 수 있다 — 매매일지처럼 하단 액세서리 문구가 이미 CTA 역할을 하는 화면에서는
/// 버튼이 둘이 되어 오히려 초점이 흐려진다.
public struct EmptyStateView: View {

    // MARK: - Property

    private let systemImageName: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    // MARK: - Body

    public init(
        systemImageName: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImageName = systemImageName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: .spacingM) {
            Image(systemName: systemImageName)
                .font(.system(size: Constants.symbolSize))
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: .spacingXS) {
                Text(title)
                    .hannunFont(.rowTitle)
                    .foregroundStyle(Color.textPrimary)

                if let message {
                    Text(message)
                        .hannunFont(.subtext)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .hannunFont(.rowTitle)
                    .hannunButtonStyle(.sheetPrimary)
                    .tint(Color.brand)
                    .padding(.top, .spacingXS)
            }
        }
        .padding(.spacingXL)
        .frame(maxWidth: .infinity)
    }
}

fileprivate enum Constants {
    /// 아이콘만 타이포 스케일 밖이다 — 텍스트가 아니라 삽화 역할이라 본문 크기에 매이지 않는다.
    static let symbolSize: CGFloat = 44
}

#if DEBUG
private struct EmptyStateViewPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingXL) {
            EmptyStateView(
                systemImageName: "chart.pie",
                title: "첫 자산을 추가해 보세요",
                message: "종목을 등록하면 자산군 비중이 여기 표시됩니다.",
                actionTitle: "종목 추가"
            ) {}

            EmptyStateView(
                systemImageName: "book.closed",
                title: "첫 매매일지를 남겨보세요",
                message: "왜 샀는지 적어두면 다음 판단이 쉬워집니다."
            )
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("빈 상태 · 라이트") {
    EmptyStateViewPreview()
        .preferredColorScheme(.light)
}

#Preview("빈 상태 · 다크") {
    EmptyStateViewPreview()
        .preferredColorScheme(.dark)
}
#endif
