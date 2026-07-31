//
//  Color+Hannun.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

/// static framework 의 Asset 은 main bundle 에 없다. 번들을 반드시 명시한다.
///
/// 값은 UI 스펙 표 그대로이며 colorset 마다 라이트/다크 두 appearance 를 갖는다.
public extension Color {

    // MARK: - 기본 팔레트

    static let backgroundPrimary = Color("backgroundPrimary", bundle: .module)
    static let surfacePrimary = Color("surfacePrimary", bundle: .module)
    static let surfaceSecondary = Color("surfaceSecondary", bundle: .module)
    static let textPrimary = Color("textPrimary", bundle: .module)
    static let textSecondary = Color("textSecondary", bundle: .module)
    /// 손익 색(빨강·파랑)과 겹치지 않도록 분리한 인디고 계열.
    static let brand = Color("brand", bundle: .module)
    /// `brand` **채움 위**에 얹는 라벨 색. 선택된 필터 칩, 액세서리 주요 액션 버튼이 쓴다.
    ///
    /// 라이트에서만 흰색이고 다크에서는 잉크다 — 다크의 `brand`(`#6E6CFF`)가 라이트보다 밝아서
    /// 흰 라벨을 얹으면 대비가 약 4.0:1 로 떨어진다(13pt Semibold 칩 라벨 기준 AA 미달).
    /// 잉크로 뒤집으면 약 4.9:1 이 된다. `brand` 를 라벨 색으로 쓰는 건
    /// **옅은 tint 배경**(`HannunTint`, 알파 12/18%) 위에서만이다 — 채움 위에 쓰면 글자가 사라진다.
    static let onBrand = Color("onBrand", bundle: .module)
    static let separator = Color("separator", bundle: .module)

    // MARK: - 손익

    /// 상승. 국내 증시 관례를 따라 **빨강**이다. 뒤집지 않는다.
    static let gain = Color("gain", bundle: .module)
    /// 하락. 국내 증시 관례를 따라 **파랑**이다.
    static let loss = Color("loss", bundle: .module)
    /// 변동 0 · 데이터 없음.
    static let neutral = Color("neutral", bundle: .module)

    // MARK: - 카테고리

    /// 도넛 섹터·리스트 dot·소계가 반드시 같은 토큰을 참조해야 한다 — 리스트가 곧 범례다.
    static let categoryCash = Color("categoryCash", bundle: .module)
    static let categoryDomestic = Color("categoryDomestic", bundle: .module)
    static let categoryForeign = Color("categoryForeign", bundle: .module)
    static let categoryEtf = Color("categoryEtf", bundle: .module)
    static let categoryCrypto = Color("categoryCrypto", bundle: .module)
}

#if DEBUG
private struct ColorTokenPreview: View {

    // MARK: - Property

    private let basePalette: [(name: String, color: Color)] = [
        ("backgroundPrimary", .backgroundPrimary),
        ("surfacePrimary", .surfacePrimary),
        ("surfaceSecondary", .surfaceSecondary),
        ("textPrimary", .textPrimary),
        ("textSecondary", .textSecondary),
        ("brand", .brand),
        ("onBrand", .onBrand),
        ("separator", .separator),
    ]

    private let profitLossPalette: [(name: String, color: Color)] = [
        ("gain", .gain),
        ("loss", .loss),
        ("neutral", .neutral),
    ]

    private let categoryPalette: [(name: String, color: Color)] = [
        ("categoryCash", .categoryCash),
        ("categoryDomestic", .categoryDomestic),
        ("categoryForeign", .categoryForeign),
        ("categoryEtf", .categoryEtf),
        ("categoryCrypto", .categoryCrypto),
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingXL) {
                section(title: "기본 팔레트", swatches: basePalette)
                section(title: "손익", swatches: profitLossPalette)
                section(title: "카테고리", swatches: categoryPalette)
            }
            .padding(.spacingL)
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private func section(title: String, swatches: [(name: String, color: Color)]) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(title)
                .hannunFont(.sectionHeading)
                .foregroundStyle(Color.textPrimary)

            ForEach(swatches, id: \.name) { swatch in
                HStack(spacing: .spacingM) {
                    RoundedRectangle(cornerRadius: .radiusS)
                        .fill(swatch.color)
                        .frame(width: 56, height: 32)
                        .overlay {
                            RoundedRectangle(cornerRadius: .radiusS)
                                .stroke(Color.separator, lineWidth: 1)
                        }

                    Text(swatch.name)
                        .hannunFont(.body)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }
}

#Preview("컬러 토큰 · 라이트") {
    ColorTokenPreview()
        .preferredColorScheme(.light)
}

#Preview("컬러 토큰 · 다크") {
    ColorTokenPreview()
        .preferredColorScheme(.dark)
}
#endif
