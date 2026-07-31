//
//  GlassRole.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

/// Liquid Glass 적용/금지 규칙과 variant 매핑을 코드로 옮긴 것.
///
/// Glass 는 "콘텐츠 위에 떠 있는 기능 레이어"에만 붙인다. 콘텐츠 자체(카드·차트·리스트·
/// 고밀도 숫자)는 불투명 서피스다. 시안의 `$glass`(`#FFFFFF99`)·`background_blur(20)`·
/// shadow 는 Liquid Glass 의 모사이므로 직접 칠하지 않는다 — `.glassEffect` 에 내장돼 있다.
public enum GlassRole: CaseIterable, Sendable {
    /// 콘텐츠 영역의 필터 칩(벤치마크·종목·카테고리). 그룹은 `GlassEffectContainer` +
    /// `glassEffectUnion` 으로 묶어 오프스크린 렌더링을 줄인다.
    case filterChip
    /// 선택된 필터 칩. 선택 상태를 brand tint 로 구분한다.
    ///
    /// `Glass.tint(_:)` 는 알파 wash 가 아니라 채도를 그대로 먹이는 채움이다.
    /// **라벨은 `onBrand`** 를 쓴다 — `brand` 를 쓰면 배경과 같은 색이라 글자가 사라진다.
    case selectedFilterChip
    /// 탭바 하단 액세서리 캡슐. **컨테이너 자체에만** 붙인다.
    case accessoryCapsule
    /// 액세서리 내부 세그먼트·칩(KRW/USD 통화 토글 포함). 캡슐이 이미 반투명이라
    /// 여기에 glass 를 다시 얹으면 두 겹이 되어 가독성이 무너진다 — 불투명 fill 을 쓴다.
    case accessoryControl
    /// 선택된 액세서리 내부 컨트롤. 라벨은 `brand` 를 쓴다.
    case selectedAccessoryControl
    /// 액세서리 내부 주요 액션(종목 추가·일지 작성). `brand` 채움 + `onBrand` 라벨.
    case accessoryPrimaryAction
    /// 성과 탭 기간 세그먼트. 액세서리가 아니라 차트 바로 아래 인라인이라 glass 를 쓴다.
    case periodSegment
    /// 카드·차트·리스트·금액 블록. 규칙상 glass 금지 영역이다.
    case contentSurface
}

public extension GlassRole {
    /// 역할에 지정된 표면 처리. `.solid` 는 "glass 금지" 판정이다.
    enum Surface: Sendable {
        case glass(Glass)
        case solid(AnyShapeStyle)
    }

    var surface: Surface {
        switch self {
        case .filterChip:
            .glass(.regular.interactive())
        case .selectedFilterChip:
            .glass(.regular.tint(.brand).interactive())
        case .accessoryCapsule:
            .glass(.regular)
        case .accessoryControl:
            .solid(AnyShapeStyle(Color.surfaceSecondary))
        case .selectedAccessoryControl:
            .solid(AnyShapeStyle(HannunTint.brandTint))
        case .accessoryPrimaryAction:
            .solid(AnyShapeStyle(Color.brand))
        case .periodSegment:
            .glass(.regular.interactive())
        case .contentSurface:
            .solid(AnyShapeStyle(Color.surfacePrimary))
        }
    }

    var usesGlass: Bool {
        switch surface {
        case .glass: true
        case .solid: false
        }
    }
}

/// sheet 하단 버튼은 `glassEffect` 가 아니라 ButtonStyle 로 처리한다.
public enum GlassButtonRole: CaseIterable, Sendable {
    /// 저장 등 주 액션.
    case sheetPrimary
    /// 취소·닫기.
    case sheetSecondary
}

public extension View {
    /// 역할이 정한 표면을 입힌다. glass 금지 역할이면 지정된 불투명 fill 로 대체된다.
    @ViewBuilder
    func hannunGlass(_ role: GlassRole, in shape: some Shape = Capsule()) -> some View {
        switch role.surface {
        case .glass(let glass):
            glassEffect(glass, in: shape)
        case .solid(let style):
            background(style, in: shape)
        }
    }

    @ViewBuilder
    func hannunButtonStyle(_ role: GlassButtonRole) -> some View {
        switch role {
        case .sheetPrimary:
            buttonStyle(.glassProminent)
        case .sheetSecondary:
            buttonStyle(.glass)
        }
    }
}

#if DEBUG
private struct GlassRolePreview: View {

    // MARK: - Property

    private let benchmarks = ["코스피", "S&P500", "나스닥", "BTC"]
    private let selectedBenchmark = "S&P500"
    private let currencies = ["KRW", "USD"]
    private let selectedCurrency = "KRW"

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingXL) {
            contentCard
            filterChips
            Spacer()
            accessoryCapsule
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text("총자산")
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            Text("₩128,450,000")
                .hannunFont(.displayAmount)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingL)
        .hannunGlass(.contentSurface, in: .rect(cornerRadius: .radiusM))
    }

    private var filterChips: some View {
        GlassEffectContainer(spacing: .spacingS) {
            HStack(spacing: .spacingS) {
                ForEach(benchmarks, id: \.self) { benchmark in
                    let isSelected = benchmark == selectedBenchmark

                    Text(benchmark)
                        .hannunFont(.pillLabel)
                        .foregroundStyle(isSelected ? Color.onBrand : Color.textPrimary)
                        .padding(.vertical, .spacingS)
                        .padding(.horizontal, .spacingM)
                        .hannunGlass(isSelected ? .selectedFilterChip : .filterChip)
                }
            }
        }
    }

    private var accessoryCapsule: some View {
        HStack(spacing: .spacingS) {
            Text("오후 12:04 시세 기준")
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            Spacer()

            HStack(spacing: .spacingXS) {
                ForEach(currencies, id: \.self) { currency in
                    let isSelected = currency == selectedCurrency

                    Text(currency)
                        .hannunFont(.pillLabel)
                        .foregroundStyle(isSelected ? Color.brand : Color.textSecondary)
                        .padding(.vertical, .spacingXS)
                        .padding(.horizontal, .spacingM)
                        .hannunGlass(isSelected ? .selectedAccessoryControl : .accessoryControl)
                }
            }
        }
        .padding(.horizontal, .spacingL)
        .frame(height: 56)
        .hannunGlass(.accessoryCapsule)
    }
}

#Preview("Glass 매핑 · 라이트") {
    GlassRolePreview()
        .preferredColorScheme(.light)
}

#Preview("Glass 매핑 · 다크") {
    GlassRolePreview()
        .preferredColorScheme(.dark)
}
#endif
