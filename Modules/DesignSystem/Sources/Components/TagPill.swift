//
//  TagPill.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 종목 태그 표식. 일지 셀에서는 읽기 전용이고, 작성 화면에서는 선택형이 된다.
///
/// 선택형이라도 glass 를 쓰지 않는다 — 폼 안의 컨트롤은 콘텐츠 레이어라 불투명이 규칙이다.
/// 콘텐츠 영역의 필터가 필요하면 `FilterChip` 을 쓴다.
public struct TagPill: View {

    // MARK: - Property

    private let title: String
    private let isSelected: Bool
    private let action: (() -> Void)?

    // MARK: - Body

    /// 읽기 전용 표시.
    public init(_ title: String) {
        self.title = title
        isSelected = false
        action = nil
    }

    /// 선택형.
    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .hannunAnimation(.selection, value: isSelected)
        } else {
            label
        }
    }

    private var label: some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(isSelected ? Color.brand : Color.textSecondary)
            .lineLimit(1)
            .padding(.vertical, .spacingXS)
            .padding(.horizontal, .spacingS)
            .background(background, in: .capsule)
    }

    private var background: AnyShapeStyle {
        isSelected ? AnyShapeStyle(HannunTint.brandTint) : AnyShapeStyle(Color.surfaceSecondary)
    }
}

#if DEBUG
private struct TagPillPreview: View {

    // MARK: - Property

    private let tickers = ["삼성전자", "AAPL", "BTC", "TIGER 미국S&P500"]

    @State private var selectedTicker = "AAPL"

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            VStack(alignment: .leading, spacing: .spacingS) {
                Text("표시용")
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: .spacingXS) {
                    ForEach(tickers, id: \.self) { ticker in
                        TagPill(ticker)
                    }
                }
            }

            VStack(alignment: .leading, spacing: .spacingS) {
                Text("선택형")
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: .spacingXS) {
                    ForEach(tickers, id: \.self) { ticker in
                        TagPill(ticker, isSelected: ticker == selectedTicker) {
                            selectedTicker = ticker
                        }
                    }
                }
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }
}

#Preview("태그 pill · 라이트") {
    TagPillPreview()
        .preferredColorScheme(.light)
}

#Preview("태그 pill · 다크") {
    TagPillPreview()
        .preferredColorScheme(.dark)
}
#endif
