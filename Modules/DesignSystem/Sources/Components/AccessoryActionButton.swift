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

    @Environment(\.colorScheme) private var colorScheme

    private let title: String?
    private let systemImageName: String?
    private let accessibilityLabel: String
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
        accessibilityLabel = title
        self.style = style
        self.action = action
    }

    /// 아이콘만 있는 44pt 원형. 매매일지 작성 버튼이 FAB 대신 쓰는 형태다.
    ///
    /// 라벨을 인자로 받는다 — 기본값을 두지 않는 이유는, 아이콘만 남은 버튼이 그 탭의 유일한
    /// 진입점인 경우가 있어서다(JR-2). 빠뜨리면 VoiceOver 사용자는 심볼 이름("pencil.line")을
    /// 듣거나 아무것도 못 듣는다.
    public init(
        systemImageName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        title = nil
        self.systemImageName = systemImageName
        self.accessibilityLabel = accessibilityLabel
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
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Function

    @ViewBuilder
    private func labeledContent(title: String) -> some View {
        switch style {
        case .primary:
            // 시각 캡슐은 라벨+세로 패딩이 정하고(Dynamic Type 추종), 44pt 는 히트 프레임 몫이다.
            fullLabel(title: title)
                .foregroundStyle(Color.onBrand)
                .padding(.vertical, .spacingS)
                .padding(.horizontal, Constants.horizontalPadding)
                .hannunGlass(.accessoryPrimaryAction)
                .frame(minHeight: .minimumTouchTarget)
                .contentShape(.capsule)

        case .secondary:
            // 폭이 모자라면 라벨을 자르는 대신 아이콘만 남긴다 — 잘린 액션 라벨을 만들지 않는다.
            ViewThatFits(in: .horizontal) {
                secondarySurface { fullLabel(title: title) }
                secondarySurface { iconOnlyLabel }
            }
        }
    }

    private func fullLabel(title: String) -> some View {
        HStack(spacing: .spacingXS) {
            if let systemImageName {
                Image(systemName: systemImageName)
                    .imageScale(.small)
                    .foregroundStyle(style == .secondary ? Color.brand : Color.onBrand)
            }

            Text(title)
                .lineLimit(1)
        }
        .hannunFont(.pillLabel)
    }

    @ViewBuilder
    private var iconOnlyLabel: some View {
        if let systemImageName {
            Image(systemName: systemImageName)
                .imageScale(.small)
                .foregroundStyle(Color.brand)
                .hannunFont(.pillLabel)
        }
    }

    /// 스트로크가 "눌리는 것"의 경계를 색이 아닌 형태로 준다 — 다크 유리 위 `brand` 라벨은
    /// 텍스트 대비가 모자라 잉크 라벨 + brand 스트로크·아이콘 조합을 쓴다. 스트로크는
    /// 그래픽 기준(3:1)이라 두 스킴 모두 통과한다.
    private func secondarySurface(@ViewBuilder content: () -> some View) -> some View {
        content()
            .foregroundStyle(colorScheme == .dark ? Color.textPrimary : Color.brand)
            .padding(.vertical, .spacingS)
            .padding(.horizontal, Constants.horizontalPadding)
            .overlay {
                Capsule().strokeBorder(Color.brand, lineWidth: Constants.strokeLineWidth)
            }
            .frame(minHeight: .minimumTouchTarget)
            .contentShape(.capsule)
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
    static let strokeLineWidth: CGFloat = 1
}

#if DEBUG
private struct AccessoryActionButtonPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            BottomAccessory {
                AccessoryActionButton("종목 추가", systemImageName: "plus", style: .primary) {}
            } trailing: {
                AccessoryActionButton(
                    "입출금 기록",
                    systemImageName: "arrow.left.arrow.right",
                    style: .secondary
                ) {}
            }

            BottomAccessory {
                AccessoryCaption("오늘의 매매를 기록해보세요")
            } trailing: {
                AccessoryActionButton("작성", systemImageName: "pencil.line") {}
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
