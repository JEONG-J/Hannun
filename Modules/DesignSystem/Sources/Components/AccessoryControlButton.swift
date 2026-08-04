//
//  AccessoryControlButton.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/3/26.
//

import SwiftUI

/// 액세서리 캡슐 오른쪽에 놓는 **상태 컨트롤** — 누르면 화면의 표시 상태가 바뀌고, 버튼 자신이
/// 그 상태를 계속 들고 있는다(통화 전환, 벤치마크 비교 on/off).
///
/// `AccessoryActionButton` 과는 하는 일이 다르다. 저쪽은 무언가를 **새로 만들거나 띄우는**
/// 액션이라 누른 뒤 버튼이 원래대로 돌아오지만, 이쪽은 누른 결과가 버튼 모양에 남는다.
/// 그래서 부호화도 다르다.
///
/// | 상태 | 면 | 라벨 |
/// |------|-----|------|
/// | 켜짐 | `brand` 채움 | `onBrand` |
/// | 꺼짐 | 채움 없음 + `brand` 1pt 스트로크 | 라이트 `brand` / 다크 `textPrimary` |
///
/// 꺼짐에서 채움을 쓰지 않는 이유는 시스템 캡슐의 유리가 이미 배경이라서다 — 불투명 슬래브를
/// 깔면 유리가 세그먼트 바처럼 가려진다. 다크에서 라벨을 잉크로 바꾸는 이유는 다크 `brand`
/// 라벨이 4.07:1 로 AA(4.5:1) 미달이기 때문이고, 스트로크는 그래픽 기준(3:1)이라 그대로 둔다.
///
/// 켜짐/꺼짐이 **한 대상의 두 상태**일 때만 `.isSelected` trait 을 붙인다(비교 on/off).
/// 통화 전환처럼 누를 때마다 대상이 바뀌는 컨트롤은 선택 상태가 아니므로 붙이지 않고,
/// 라벨에는 **지금 상태**를 적는다 — `KRW` 가 보이면 지금 원화로 보고 있다는 뜻이다.
/// 눌러서 바뀔 대상은 `accessibilityHint` 가 말한다(`NetWorthAccessory` 의 통화 전환·
/// 성과 탭의 일별/월별 전환과 같은 문법).
public struct AccessoryControlButton: View {

    // MARK: - Property

    @Environment(\.colorScheme) private var colorScheme

    private let title: String?
    private let systemImageName: String?
    private let accessibilityLabel: String
    private let isOn: Bool
    private let indicatesSelection: Bool
    private let action: () -> Void

    // MARK: - Body

    /// - Parameters:
    ///   - isOn: 켜짐이면 채움, 꺼짐이면 스트로크.
    ///   - indicatesSelection: 켜짐/꺼짐이 한 대상의 두 상태일 때만 `true`. 통화 전환처럼
    ///     누를 때마다 대상이 바뀌는 컨트롤은 `false` 로 두고 라벨이 **지금 상태**를 말하게
    ///     한다 — 바뀔 대상은 `accessibilityHint` 가 맡는다.
    ///   - accessibilityLabel: 비우면 `title` 을 그대로 읽는다.
    public init(
        _ title: String,
        systemImageName: String? = nil,
        isOn: Bool,
        indicatesSelection: Bool = true,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImageName = systemImageName
        self.accessibilityLabel = accessibilityLabel ?? title
        self.isOn = isOn
        self.indicatesSelection = indicatesSelection
        self.action = action
    }

    /// 아이콘만 있는 형태. 라벨은 반드시 받는다 — 심볼 이름이 읽히면 안 된다.
    public init(
        systemImageName: String,
        accessibilityLabel: String,
        isOn: Bool,
        indicatesSelection: Bool = true,
        action: @escaping () -> Void
    ) {
        title = nil
        self.systemImageName = systemImageName
        self.accessibilityLabel = accessibilityLabel
        self.isOn = isOn
        self.indicatesSelection = indicatesSelection
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            label
                .hannunFont(.pillLabel)
                .lineLimit(1)
                .foregroundStyle(labelColor)
                .padding(.vertical, .spacingS)
                .padding(.horizontal, Constants.horizontalPadding)
                .background(background, in: .capsule)
                .overlay {
                    if !isOn {
                        Capsule()
                            .strokeBorder(Color.brand, lineWidth: Constants.strokeLineWidth)
                    }
                }
                .frame(minHeight: .minimumTouchTarget)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(indicatesSelection && isOn ? .isSelected : [])
        .hannunAnimation(.selection, value: isOn)
    }

    // MARK: - Function

    @ViewBuilder
    private var label: some View {
        HStack(spacing: .spacingXS) {
            if let systemImageName {
                Image(systemName: systemImageName)
                    .imageScale(.small)
            }

            if let title {
                Text(title)
            }
        }
    }

    /// 켜짐만 채운다. 투명도 감소에서는 `brand` 원색이라 유리와 무관하게 그대로 성립한다.
    private var background: AnyShapeStyle {
        isOn ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color.clear)
    }

    /// 꺼짐 다크에서 `brand` 라벨은 4.07:1 로 AA 미달 — 잉크로 바꾸고 경계는 스트로크가 맡는다.
    private var labelColor: Color {
        if isOn { return .onBrand }
        return colorScheme == .dark ? .textPrimary : .brand
    }
}

fileprivate enum Constants {
    /// `AccessoryActionButton` 과 같은 값. 두 컨트롤이 한 캡슐에 나란히 놓여도 폭이 맞는다.
    static let horizontalPadding: CGFloat = 14
    static let strokeLineWidth: CGFloat = 1
}

#if DEBUG
private struct AccessoryControlButtonPreview: View {

    // MARK: - Property

    @State private var isComparing = true
    @State private var showsDollar = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            labeled("상태 컨트롤 — 켜짐 채움 / 꺼짐 스트로크") {
                HStack(spacing: .spacingM) {
                    AccessoryControlButton("비교", isOn: true) {}
                    AccessoryControlButton("비교", isOn: false) {}
                }
            }

            labeled("아이콘 동반") {
                HStack(spacing: .spacingM) {
                    AccessoryControlButton(
                        "비교",
                        systemImageName: "chart.line.uptrend.xyaxis",
                        isOn: isComparing
                    ) {
                        isComparing.toggle()
                    }
                }
            }

            labeled("전환형 — 라벨이 지금 상태를 말한다 (선택 상태 아님)") {
                AccessoryControlButton(
                    showsDollar ? "USD" : "KRW",
                    isOn: false,
                    indicatesSelection: false,
                    accessibilityLabel: showsDollar ? "지금 미국 달러" : "지금 원화"
                ) {
                    showsDollar.toggle()
                }
                .accessibilityHint(showsDollar ? "두 번 탭하면 원화로 바꿉니다" : "두 번 탭하면 미국 달러로 바꿉니다")
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private func labeled(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            content()
        }
    }
}

#Preview("액세서리 상태 컨트롤 · 라이트") {
    AccessoryControlButtonPreview()
        .preferredColorScheme(.light)
}

#Preview("액세서리 상태 컨트롤 · 다크") {
    AccessoryControlButtonPreview()
        .preferredColorScheme(.dark)
}
#endif
