//
//  HannunTint.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

/// pill·칩 배경에 쓰는 원색의 옅은 tint.
///
/// 알파가 라이트 12% / 다크 18% 로 갈리므로 colorset 이나 상수 색으로 굳히지 않는다.
/// `resolve(in:)` 안에서 `colorScheme` 을 읽어 원색에서 파생시키면 원색 하나만 바꿔도
/// tint 가 따라오고, 라이트/다크 알파 차이가 한 곳에만 남는다.
public struct HannunTint: ShapeStyle {

    // MARK: - Property

    private let base: Color

    // MARK: - Function

    fileprivate init(base: Color) {
        self.base = base
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        let boosted = environment.accessibilityReduceTransparency
        let opacity = environment.colorScheme == .dark
            ? (boosted ? Constants.darkSchemeBoostedOpacity : Constants.darkSchemeOpacity)
            : (boosted ? Constants.lightSchemeBoostedOpacity : Constants.lightSchemeOpacity)
        return base.opacity(opacity)
    }
}

/// 리딩 닷으로 바로 쓰기 위한 진입점 — `.background(.gainTint, in: .capsule)`.
public extension ShapeStyle where Self == HannunTint {
    static var brandTint: HannunTint { HannunTint(base: .brand) }
    static var gainTint: HannunTint { HannunTint(base: .gain) }
    static var lossTint: HannunTint { HannunTint(base: .loss) }
    static var neutralTint: HannunTint { HannunTint(base: .neutral) }

    /// 벤치마크 칩처럼 원색이 호출부에서 정해지는 wash. 카테고리색 확장 진입점이다 —
    /// 신규 raw 색 없이 파생 규칙(12%/18%, 투명도 감소 시 상향)만 넓힌다.
    static func wash(_ base: Color) -> HannunTint { HannunTint(base: base) }
}

fileprivate enum Constants {
    static let lightSchemeOpacity: Double = 0.12
    static let darkSchemeOpacity: Double = 0.18
    /// 투명도 감소에서는 유리 대신 불투명 면 위에 놓이므로 wash 를 진하게 민다.
    static let lightSchemeBoostedOpacity: Double = 0.20
    static let darkSchemeBoostedOpacity: Double = 0.28
}

#if DEBUG
private struct TintTokenPreview: View {

    // MARK: - Property

    private let tints: [(name: String, tint: HannunTint, foreground: Color)] = [
        ("brandTint", .brandTint, .brand),
        ("gainTint", .gainTint, .gain),
        ("lossTint", .lossTint, .loss),
        ("neutralTint", .neutralTint, .neutral),
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            Text("tint 는 원색 + 알파(라이트 12% / 다크 18%) 파생값이다")
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            ForEach(tints, id: \.name) { item in
                HStack(spacing: .spacingM) {
                    Text("+12.34%")
                        .hannunFont(.pillLabel)
                        .foregroundStyle(item.foreground)
                        .padding(.vertical, .spacingXS)
                        .padding(.horizontal, .spacingS)
                        .background(item.tint, in: .capsule)

                    Text(item.name)
                        .hannunFont(.body)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingL)
        .background(Color.backgroundPrimary)
    }
}

#Preview("tint 토큰 · 라이트") {
    TintTokenPreview()
        .preferredColorScheme(.light)
}

#Preview("tint 토큰 · 다크") {
    TintTokenPreview()
        .preferredColorScheme(.dark)
}
#endif
