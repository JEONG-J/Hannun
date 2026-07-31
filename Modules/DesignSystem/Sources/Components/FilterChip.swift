//
//  FilterChip.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 칩이 어느 레이어에 놓이는지. `ChipGroup` 이 환경에 심어 주고 개별 칩이 읽는다.
public enum ChipAppearance: Equatable, Sendable {
    /// 콘텐츠 영역 — Liquid Glass 를 쓴다.
    case content
    /// 액세서리 캡슐 내부 — 캡슐이 이미 반투명이라 glass 를 겹치지 않고 불투명 fill 을 쓴다.
    case accessory
}

/// 필터·다중 선택 칩. 선택 상태를 tint 로 구분한다.
///
/// - Parameter tint: 벤치마크 칩처럼 선택 색이 차트 라인 색을 따라가야 할 때만 넣는다.
///   비우면 `brand` 다. 칩이 곧 범례이므로 라인 색과 칩 색은 반드시 같아야 한다.
public struct FilterChip: View {

    // MARK: - Property

    private let title: String
    private let isSelected: Bool
    private let isEnabled: Bool
    private let tint: Color?
    private let action: () -> Void

    // MARK: - Body

    public init(
        _ title: String,
        isSelected: Bool,
        isEnabled: Bool = true,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .hannunFont(.pillLabel)
                .lineLimit(1)
                .modifier(
                    ChipSurface(isSelected: isSelected, isEnabled: isEnabled, tint: tint)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .hannunAnimation(.selection, value: isSelected)
    }
}

/// 라벨 색·표면·union 참여 여부를 한 번에 정하는 곳.
///
/// 선택 칩 라벨이 `onBrand` 인 이유: `Glass.tint(_:)` 는 알파 wash 가 아니라 채도 그대로의
/// 채움이다. `brand` 라벨을 얹으면 배경과 같은 색이라 글자가 사라진다.
private struct ChipSurface: ViewModifier {

    // MARK: - Property

    @Environment(\.chipAppearance) private var appearance
    @Environment(\.chipUnionNamespace) private var unionNamespace

    let isSelected: Bool
    let isEnabled: Bool
    let tint: Color?

    // MARK: - Body

    func body(content: Content) -> some View {
        switch appearance {
        case .content:
            contentSurface(content)
        case .accessory:
            accessorySurface(content)
        }
    }

    // MARK: - Function

    /// 선택된 칩만 `glassEffectUnion` 밖에 둔다.
    ///
    /// union 은 참여 뷰들의 glass 를 하나의 레이어로 병합하고, 병합된 형상은 재질 파라미터도
    /// 하나로 합친다. iOS 26.5 시뮬레이터에서 직접 렌더해 보니 선택 칩을 union 에 넣으면 그 칩의
    /// `tint` 가 이웃으로 번지는 정도가 아니라 **아예 증발한다** — 무채색 유리 위에 `onBrand`
    /// 라벨만 남아 선택 상태를 읽을 수 없다. 비선택 칩만 묶으면 선택 표시는 살아 있고, union 의
    /// 목적인 오프스크린 렌더링 절감은 대상이 n-1 개라 사실상 그대로다.
    ///
    /// 대신 비선택 칩들은 하나의 트랙으로 합쳐지고 선택 칩이 그 위에 얹힌 모양이 된다 —
    /// union 을 쓰는 이상 개별 캡슐 경계는 포기해야 한다.
    @ViewBuilder
    private func contentSurface(_ content: Content) -> some View {
        if isSelected {
            selectedContentSurface(content)
        } else if let unionNamespace {
            content
                .foregroundStyle(unselectedLabelColor)
                .padding(.vertical, .spacingS)
                .padding(.horizontal, Constants.horizontalPadding)
                .hannunGlass(.filterChip)
                .glassEffectUnion(id: Constants.unionIdentifier, namespace: unionNamespace)
        } else {
            content
                .foregroundStyle(unselectedLabelColor)
                .padding(.vertical, .spacingS)
                .padding(.horizontal, Constants.horizontalPadding)
                .hannunGlass(.filterChip)
        }
    }

    @ViewBuilder
    private func selectedContentSurface(_ content: Content) -> some View {
        let label = content
            .foregroundStyle(Color.onBrand)
            .padding(.vertical, .spacingS)
            .padding(.horizontal, Constants.horizontalPadding)

        if let tint {
            // GlassRole.selectedFilterChip 은 brand 로 고정돼 있어 벤치마크별 색을 표현하지 못한다.
            label.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
            label.hannunGlass(.selectedFilterChip)
        }
    }

    /// 액세서리 내부는 glass 금지. 선택 색이 지정되면 그 색으로 **채우고**(범례 역할),
    /// 지정되지 않으면 brand tint + brand 라벨로 떨어진다.
    @ViewBuilder
    private func accessorySurface(_ content: Content) -> some View {
        content
            .foregroundStyle(accessoryLabelColor)
            .padding(.horizontal, Constants.horizontalPadding)
            .frame(minHeight: .minimumTouchTarget)
            .background(accessoryBackground, in: .capsule)
    }

    private var accessoryBackground: AnyShapeStyle {
        guard isSelected else { return AnyShapeStyle(Color.surfaceSecondary) }
        guard let tint else { return AnyShapeStyle(HannunTint.brandTint) }
        return AnyShapeStyle(tint)
    }

    private var accessoryLabelColor: Color {
        guard isSelected else { return isEnabled ? .textSecondary : .neutral }
        return tint == nil ? .brand : .onBrand
    }

    private var unselectedLabelColor: Color {
        isEnabled ? .textPrimary : .textSecondary
    }
}

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = 14
    /// 그룹 안 비선택 칩은 전부 같은 union 에 속한다.
    static let unionIdentifier = "unselectedFilterChip"
}

#if DEBUG
private struct FilterChipPreview: View {

    // MARK: - Property

    private let categories = ["전체", "현금", "국내주식", "해외주식", "ETF", "코인"]
    private let benchmarks: [(name: String, color: Color)] = [
        ("코스피", .categoryDomestic),
        ("S&P500", .categoryForeign),
        ("나스닥", .categoryEtf),
        ("BTC", .categoryCrypto),
    ]

    @State private var selectedCategory = "국내주식"
    @State private var selectedBenchmark = "S&P500"

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXL) {
            labeled("콘텐츠 영역 (glass · union)") {
                ChipGroup {
                    ForEach(categories, id: \.self) { category in
                        FilterChip(category, isSelected: category == selectedCategory) {
                            selectedCategory = category
                        }
                    }
                }
            }

            labeled("비활성 포함") {
                ChipGroup(scrollsHorizontally: false) {
                    FilterChip("전체", isSelected: true) {}
                    FilterChip("코인", isSelected: false) {}
                    FilterChip("ETF", isSelected: false, isEnabled: false) {}
                }
            }

            labeled("액세서리 내부 (불투명 · 벤치마크 색)") {
                ChipGroup(appearance: .accessory, scrollsHorizontally: false) {
                    ForEach(benchmarks, id: \.name) { benchmark in
                        FilterChip(
                            benchmark.name,
                            isSelected: benchmark.name == selectedBenchmark,
                            tint: benchmark.color
                        ) {
                            selectedBenchmark = benchmark.name
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

    private func labeled(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            content()
        }
    }
}

#Preview("필터 칩 · 라이트") {
    FilterChipPreview()
        .preferredColorScheme(.light)
}

#Preview("필터 칩 · 다크") {
    FilterChipPreview()
        .preferredColorScheme(.dark)
}
#endif
