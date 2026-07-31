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
        let opacity = environment.colorScheme == .dark
            ? Constants.darkSchemeOpacity
            : Constants.lightSchemeOpacity
        return base.opacity(opacity)
    }
}

/// 리딩 닷으로 바로 쓰기 위한 진입점 — `.background(.gainTint, in: .capsule)`.
public extension ShapeStyle where Self == HannunTint {
    static var brandTint: HannunTint { HannunTint(base: .brand) }
    static var gainTint: HannunTint { HannunTint(base: .gain) }
    static var lossTint: HannunTint { HannunTint(base: .loss) }
    static var neutralTint: HannunTint { HannunTint(base: .neutral) }
}

fileprivate enum Constants {
    static let lightSchemeOpacity: Double = 0.12
    static let darkSchemeOpacity: Double = 0.18
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
