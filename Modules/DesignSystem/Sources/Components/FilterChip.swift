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

/// 필터·다중 선택 칩. 선택 상태를 채움과 웨이트로 구분한다.
///
/// - Parameter tint: 카테고리·벤치마크처럼 칩이 곧 범례일 때만 넣는다. 비우면 `brand` 다.
///   tint 는 **채움색이 아니라 범례색**이다 — 원색 채움 + 흰 라벨은 카테고리색에서
///   최악 1.9:1 이라 봉인했고, 색은 dot 이 나른다.
public struct FilterChip: View {

    // MARK: - Property

    @Environment(\.chipAppearance) private var appearance

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
            HStack(spacing: .spacingXS) {
                if let dotColor = legendDotColor {
                    CategoryDot(color: dotColor)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .hannunFont(labelStyle)
                    .lineLimit(1)
            }
            .modifier(
                ChipSurface(isSelected: isSelected, isEnabled: isEnabled, tint: tint)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Constants.disabledOpacity)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .hannunAnimation(.selection, value: isSelected)
    }

    // MARK: - Function

    /// 액세서리 비선택만 Regular — 웨이트가 선택 신호의 실제 부호화 채널이다.
    /// 색(wash·dot)과 `.isSelected` trait 까지 합쳐 삼중 부호화가 된다.
    private var labelStyle: HannunTextStyle {
        appearance == .accessory && !isSelected ? .caption : .pillLabel
    }

    /// 범례 색이 지정된 칩은 dot 을 **상시** 배치한다 — 선택 전환 시 폭이 변하지 않아
    /// 이웃 칩이 밀리는 재배치 점프가 없다.
    ///
    /// 색은 레이어마다 다르다. 액세서리는 선택 칩만 wash 를 깔므로 dot 이 선택 신호를
    /// 겸해 비선택을 중립색으로 죽이고, 콘텐츠는 유리/brand 유리로 이미 선택이 갈리므로
    /// dot 은 순수 범례다. 단 brand 채움 위에서는 카테고리색이 최악 2:1 로 묻혀
    /// 선택 칩만 `onBrand` 로 바꾼다.
    private var legendDotColor: Color? {
        guard let tint else { return nil }
        switch appearance {
        case .content:
            return isSelected ? .onBrand : tint
        case .accessory:
            return isSelected ? tint : .neutral
        }
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.colorScheme) private var colorScheme

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

    /// 선택 채움은 tint 와 무관하게 `brand` 하나다. 카테고리 원색으로 채우면 `onBrand`
    /// 라벨 대비가 주황 계열에서 1.9:1 까지 떨어지는데, 라벨을 잉크로 바꿔도 다크의
    /// 밝은 카테고리색 위에서 3:1 을 못 넘겨 어느 스킴에서도 성립하지 않았다.
    /// 카테고리 식별은 라벨 텍스트와 범례 dot 이 맡는다.
    private func selectedContentSurface(_ content: Content) -> some View {
        content
            .foregroundStyle(Color.onBrand)
            .padding(.vertical, .spacingS)
            .padding(.horizontal, Constants.horizontalPadding)
            .hannunGlass(.selectedFilterChip)
    }

    /// 액세서리 내부는 glass 금지에 더해 **비선택 채움도 금지**다 — 시스템 캡슐의 유리가
    /// 곧 배경이고, 불투명 슬래브를 깔면 유리가 세그먼트 바처럼 가려진다. 선택만 원색의
    /// 옅은 wash 를 얹는다. 시각 캡슐은 라벨+세로 패딩이 정하고(Dynamic Type 추종),
    /// 44pt 터치 타깃은 바깥 히트 프레임이 보장한다.
    @ViewBuilder
    private func accessorySurface(_ content: Content) -> some View {
        content
            .foregroundStyle(accessoryLabelColor)
            .padding(.vertical, .spacingS)
            .padding(.horizontal, Constants.horizontalPadding)
            .background(accessoryBackground, in: .capsule)
            .overlay {
                if let boundary = accessoryBoundaryColor {
                    Capsule().strokeBorder(boundary, lineWidth: Constants.boundaryLineWidth)
                }
            }
            .frame(minHeight: .minimumTouchTarget)
            .contentShape(.capsule)
    }

    private var accessoryBackground: AnyShapeStyle {
        guard isSelected else { return AnyShapeStyle(Color.clear) }
        guard let tint else { return AnyShapeStyle(HannunTint.brandTint) }
        return AnyShapeStyle(HannunTint.wash(tint))
    }

    /// 투명도 감소·대비 증가에서는 "채움 없음"이 경계 상실이 되므로 스트로크로 복원한다.
    private var accessoryBoundaryColor: Color? {
        guard reduceTransparency || colorSchemeContrast == .increased else { return nil }
        return isSelected ? (tint ?? .brand) : .separator
    }

    /// wash 위 라벨은 잉크가 원칙 — 다크 `brand` on wash 는 3.25:1 로 AA 미달이다.
    /// brand wash(통화 토글)만 라이트에 한해 brand 라벨을 유지한다. 비활성 감쇠는
    /// 칩 전체 opacity 가 맡으므로 여기서는 색을 갈라 쓰지 않는다.
    private var accessoryLabelColor: Color {
        guard isSelected else { return .textSecondary }
        guard tint == nil else { return .textPrimary }
        return colorScheme == .dark ? .textPrimary : .brand
    }

    private var unselectedLabelColor: Color {
        isEnabled ? .textPrimary : .textSecondary
    }
}

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = 14
    /// 그룹 안 비선택 칩은 전부 같은 union 에 속한다.
    static let unionIdentifier = "unselectedFilterChip"
    /// 비활성은 비선택과 색이 같아(neutral == textSecondary) 감쇠로 가른다. [게이트 대기 G6]
    static let disabledOpacity: Double = 0.4
    /// 접근성 폴백 스트로크 두께.
    static let boundaryLineWidth: CGFloat = 1
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

            labeled("콘텐츠 · 범례 dot (선택 채움은 brand 고정)") {
                ChipGroup(scrollsHorizontally: false) {
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
