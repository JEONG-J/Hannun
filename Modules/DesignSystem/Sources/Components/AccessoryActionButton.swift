//
//  AccessoryActionButton.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 액세서리 내부 액션의 비중. 캡슐 하나에 primary 는 하나만 둔다.
public enum AccessoryActionStyle: CaseIterable, Sendable {
    /// 생성 액션 — `brand` 채움 + `onBrand` 라벨.
    case primary
    /// 보조 이동 — 채움 없이 라벨만.
    case secondary
}

/// 액세서리 캡슐 안에 들어가는 액션 버튼.
///
/// glass 를 쓰지 않는다 — 캡슐이 이미 반투명이라 그 위에 glass 버튼을 얹으면 두 겹이 된다.
/// 파괴적 동작(삭제·초기화)은 이 자리에 두지 않는다. 액세서리는 보조 컨트롤 전용이다.
public struct AccessoryActionButton: View {

    // MARK: - Property

    private let title: String?
    private let systemImageName: String?
    private let style: AccessoryActionStyle
    private let action: () -> Void

    // MARK: - Body

    public init(
        _ title: String,
        systemImageName: String? = nil,
        style: AccessoryActionStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImageName = systemImageName
        self.style = style
        self.action = action
    }

    /// 아이콘만 있는 44pt 원형. 매매일지 작성 버튼이 FAB 대신 쓰는 형태다.
    public init(systemImageName: String, action: @escaping () -> Void) {
        title = nil
        self.systemImageName = systemImageName
        style = .primary
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let title {
                labeledContent(title: title)
            } else {
                circularContent
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Function

    @ViewBuilder
    private func labeledContent(title: String) -> some View {
        let label = HStack(spacing: .spacingXS) {
            if let systemImageName {
                Image(systemName: systemImageName)
                    .imageScale(.small)
            }

            Text(title)
                .lineLimit(1)
        }
        .hannunFont(.pillLabel)
        .foregroundStyle(style == .primary ? Color.onBrand : Color.textPrimary)
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(minHeight: .minimumTouchTarget)

        switch style {
        case .primary:
            label.hannunGlass(.accessoryPrimaryAction)
        case .secondary:
            // 보조 액션은 채움이 없다. 캡슐 안에서 주 액션과 비중을 갈라 놓기 위한 규칙이다.
            label.contentShape(.capsule)
        }
    }

    @ViewBuilder
    private var circularContent: some View {
        if let systemImageName {
            Image(systemName: systemImageName)
                .hannunFont(.rowTitle)
                .foregroundStyle(Color.onBrand)
                .frame(width: .minimumTouchTarget, height: .minimumTouchTarget)
                .hannunGlass(.accessoryPrimaryAction, in: .circle)
        }
    }
}

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = 14
}

#if DEBUG
private struct AccessoryActionButtonPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            BottomAccessory {
                AccessoryActionButton("종목 추가", systemImageName: "plus", style: .primary) {}

                Spacer(minLength: .spacingS)

                AccessoryActionButton(
                    "입출금 기록",
                    systemImageName: "arrow.left.arrow.right",
                    style: .secondary
                ) {}
            }

            BottomAccessory {
                Label("오늘의 매매를 기록해보세요", systemImage: "sparkles")
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.leading, .spacingS)

                Spacer(minLength: .spacingS)

                AccessoryActionButton(systemImageName: "pencil.line") {}
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("액세서리 액션 · 라이트") {
    AccessoryActionButtonPreview()
        .preferredColorScheme(.light)
}

#Preview("액세서리 액션 · 다크") {
    AccessoryActionButtonPreview()
        .preferredColorScheme(.dark)
}
#endif
