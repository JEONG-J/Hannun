//
//  ChipGroup.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 칩을 묶는 컨테이너. 선택 상태는 갖지 않고 배치와 glass 그룹핑만 책임진다.
///
/// 콘텐츠 영역에서는 `GlassEffectContainer` 로 감싸 오프스크린 렌더링을 줄이고, union 에 쓸
/// 네임스페이스를 환경으로 내려보낸다. 액세서리 영역에서는 glass 자체를 쓰지 않으므로
/// 컨테이너도 만들지 않는다 — 빈 glass 컨테이너는 비용만 남기고 얻는 게 없다.
public struct ChipGroup<Content: View>: View {

    // MARK: - Property

    @Namespace private var unionNamespace

    private let appearance: ChipAppearance
    private let scrollsHorizontally: Bool
    private let content: Content

    // MARK: - Body

    public init(
        appearance: ChipAppearance = .content,
        scrollsHorizontally: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.appearance = appearance
        self.scrollsHorizontally = scrollsHorizontally
        self.content = content()
    }

    public var body: some View {
        chipLayout
            .environment(\.chipAppearance, appearance)
            .environment(\.chipUnionNamespace, appearance == .content ? unionNamespace : nil)
    }

    @ViewBuilder
    private var chipLayout: some View {
        if scrollsHorizontally {
            ScrollView(.horizontal) { chipRow }
                .scrollIndicators(.hidden)
        } else {
            chipRow
        }
    }

    @ViewBuilder
    private var chipRow: some View {
        switch appearance {
        case .content:
            GlassEffectContainer(spacing: .spacingS) {
                HStack(spacing: .spacingS) { content }
            }
        case .accessory:
            HStack(spacing: .spacingXS) { content }
        }
    }
}

extension EnvironmentValues {
    /// 칩이 놓인 레이어. 개별 `FilterChip` 이 표면을 고를 때 읽는다.
    @Entry var chipAppearance: ChipAppearance = .content
    /// 비선택 칩을 하나의 glass 레이어로 병합할 때 쓰는 네임스페이스.
    /// `nil` 이면 union 없이 개별 glass 로 그린다.
    @Entry var chipUnionNamespace: Namespace.ID?
}

#if DEBUG
private struct ChipGroupPreview: View {

    // MARK: - Property

    private let holdings = ["전체", "삼성전자", "AAPL", "NVDA", "BTC", "TIGER 미국S&P500"]

    @State private var selectedHoldings: Set<String> = ["AAPL"]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXL) {
            VStack(alignment: .leading, spacing: .spacingS) {
                Text("가로 스크롤 · 다중 선택")
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                ChipGroup {
                    ForEach(holdings, id: \.self) { holding in
                        FilterChip(holding, isSelected: selectedHoldings.contains(holding)) {
                            toggle(holding)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: .spacingS) {
                Text("스크롤 없음 · 단일 선택")
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                ChipGroup(scrollsHorizontally: false) {
                    ForEach(holdings.prefix(3), id: \.self) { holding in
                        FilterChip(holding, isSelected: selectedHoldings.contains(holding)) {
                            selectedHoldings = [holding]
                        }
                    }
                }
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private func toggle(_ holding: String) {
        if selectedHoldings.contains(holding) {
            selectedHoldings.remove(holding)
        } else {
            selectedHoldings.insert(holding)
        }
    }
}

#Preview("칩 그룹 · 라이트") {
    ChipGroupPreview()
        .preferredColorScheme(.light)
}

#Preview("칩 그룹 · 다크") {
    ChipGroupPreview()
        .preferredColorScheme(.dark)
}
#endif
