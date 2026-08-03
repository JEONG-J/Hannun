//
//  TagPill.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 종목 태그 표식. 일지 셀에서는 읽기 전용이고, 작성 화면에서는 선택형이 된다.
///
/// 분류를 주면 캡슐이 그 분류색을 입어 이름을 읽기 전에 무슨 자산인지 구분된다. 다만 **재질은
/// 자리에 따라 갈린다** — 읽기 전용은 분류색 `.clear` 유리(`GlassRole.categoryTag`)고, 작성 폼의
/// 선택형은 같은 색의 불투명 wash 다. 폼 안의 컨트롤은 콘텐츠 레이어라 불투명이 규칙이라서
/// (UI 스펙 §5) 색만 맞추고 유리는 쓰지 않는다.
///
/// 콘텐츠 영역의 필터가 필요하면 `FilterChip` 을 쓴다.
public struct TagPill: View {

    // MARK: - Property

    private let title: String
    private let category: AssetCategory?
    private let isSelected: Bool
    private let action: (() -> Void)?

    // MARK: - Body

    /// 읽기 전용 표시. 분류를 주면 캡슐이 분류색 유리가 된다.
    public init(_ title: String, category: AssetCategory? = nil) {
        self.title = title
        self.category = category
        isSelected = false
        action = nil
    }

    /// 선택형.
    public init(
        _ title: String,
        category: AssetCategory? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.category = category
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

    @ViewBuilder
    private var label: some View {
        if let category, action == nil {
            text.hannunGlass(.categoryTag(category), in: .capsule)
        } else {
            text.background(background, in: .capsule)
        }
    }

    private var text: some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.vertical, .spacingXS)
            .padding(.horizontal, .spacingS)
    }

    /// 분류색 유리 위에서는 글자까지 같은 색으로 칠하지 않는다 — 캡슐이 이미 분류를 말하고
    /// 있고, 옅은 tint 위의 원색 글자는 대비부터 무너진다. 선택형은 반대로 채움이 옅은 wash
    /// 뿐이라 글자가 색을 들어야 선택이 보인다.
    private var foreground: Color {
        if action == nil {
            return category == nil ? .textSecondary : .textPrimary
        }

        guard isSelected else { return .textSecondary }
        return category?.color ?? .brand
    }

    private var background: AnyShapeStyle {
        guard isSelected else { return AnyShapeStyle(Color.surfaceSecondary) }
        return AnyShapeStyle(HannunTint.wash(category?.color ?? .brand))
    }
}

#if DEBUG
private struct TagPillPreview: View {

    // MARK: - Property

    private let tickers: [(name: String, category: AssetCategory)] = [
        ("삼성전자", .domesticStock),
        ("AAPL", .overseasStock),
        ("BTC", .crypto),
        ("TIGER 미국S&P500", .etf),
    ]

    @State private var selectedTicker = "AAPL"

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            labeled("표시용 · 분류색 유리") {
                ForEach(tickers, id: \.name) { ticker in
                    TagPill(ticker.name, category: ticker.category)
                }
            }

            labeled("표시용 · 분류 없음") {
                ForEach(tickers, id: \.name) { ticker in
                    TagPill(ticker.name)
                }
            }

            labeled("선택형 · 폼용(불투명)") {
                ForEach(tickers, id: \.name) { ticker in
                    TagPill(
                        ticker.name,
                        category: ticker.category,
                        isSelected: ticker.name == selectedTicker
                    ) {
                        selectedTicker = ticker.name
                    }
                }
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 유리는 뒤에 무언가 있어야 보이므로 카드 면 위에 얹어 실제 자리와 같게 둔다.
        .background(Color.surfacePrimary)
    }

    // MARK: - Function

    private func labeled(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: .spacingXS) { content() }
        }
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
