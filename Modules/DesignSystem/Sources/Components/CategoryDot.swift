//
//  CategoryDot.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 카테고리 색 원형 표식. 도넛 섹터와 같은 토큰을 참조해야 리스트가 범례 역할을 한다.
public struct CategoryDot: View {

    // MARK: - Property

    private let color: Color

    // MARK: - Body

    public init(_ category: AssetCategory) {
        color = category.color
    }

    /// 벤치마크 라인처럼 카테고리가 아닌 계열의 범례로 쓸 때만 색을 직접 넣는다.
    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: Constants.diameter, height: Constants.diameter)
    }
}

fileprivate enum Constants {
    static let diameter: CGFloat = 8
}

#if DEBUG
private struct CategoryDotPreview: View {

    // MARK: - Property

    private let categoryNames: [AssetCategory: String] = [
        .cash: "현금",
        .domesticStock: "국내주식",
        .overseasStock: "해외주식",
        .etf: "ETF",
        .crypto: "코인",
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            ForEach(AssetCategory.allCases, id: \.self) { category in
                HStack(spacing: .spacingXS) {
                    CategoryDot(category)

                    Text(categoryNames[category] ?? category.rawValue)
                        .hannunFont(.subtext)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            HStack(spacing: .spacingXS) {
                CategoryDot(color: .brand)

                Text("내 수익률 (직접 지정 색)")
                    .hannunFont(.subtext)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }
}

#Preview("카테고리 dot · 라이트") {
    CategoryDotPreview()
        .preferredColorScheme(.light)
}

#Preview("카테고리 dot · 다크") {
    CategoryDotPreview()
        .preferredColorScheme(.dark)
}
#endif
