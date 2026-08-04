//
//  GlassRole.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// Liquid Glass 적용/금지 규칙과 variant 매핑을 코드로 옮긴 것.
///
/// Glass 는 "콘텐츠 위에 떠 있는 기능 레이어"에만 붙인다. 콘텐츠 자체(카드·차트·리스트·
/// 고밀도 숫자)는 불투명 서피스다. 시안의 `$glass`(`#FFFFFF99`)·`background_blur(20)`·
/// shadow 는 Liquid Glass 의 모사이므로 직접 칠하지 않는다 — `.glassEffect` 에 내장돼 있다.
///
/// 탭바 하단 액세서리 **캡슐 자체**의 역할은 여기 없다. 시스템이
/// `tabViewBottomAccessory(content:)` 컨테이너에 이미 재질과 크기를 입히므로 우리가 그릴 면이
/// 아니다 — 안에서 한 번 더 얹으면 glass 위 glass 가 되어 테두리가 사라진다 (`BottomAccessory`).
///
/// `CaseIterable` 이 아니다 — `categoryTag` 이 분류를 달고 다녀서 "모든 역할" 이 유한 목록으로
/// 떨어지지 않는다. 역할을 훑어야 할 곳도 없다(프리뷰는 필요한 것만 골라 그린다).
public enum GlassRole: Sendable {
    /// 콘텐츠 영역의 필터 칩(벤치마크·종목·카테고리). 그룹은 `GlassEffectContainer` +
    /// `glassEffectUnion` 으로 묶어 오프스크린 렌더링을 줄인다.
    case filterChip
    /// 선택된 필터 칩. 선택 상태를 brand tint 로 구분한다.
    ///
    /// `Glass.tint(_:)` 는 알파 wash 가 아니라 채도를 그대로 먹이는 채움이다.
    /// **라벨은 `onBrand`** 를 쓴다 — `brand` 를 쓰면 배경과 같은 색이라 글자가 사라진다.
    case selectedFilterChip
    /// 액세서리 내부 세그먼트·칩의 **비선택** 상태(KRW/USD 통화 토글 포함). 시스템 캡슐의
    /// 유리가 곧 배경이므로 채움을 얹지 않는다 — 채움은 선택(`selectedAccessoryControl`)과
    /// 주 액션에만 있다. 투명도 감소·대비 증가의 스트로크 폴백은 `FilterChip` 이 처리한다.
    case accessoryControl
    /// 선택된 액세서리 내부 컨트롤. 라벨은 `brand` 를 쓴다.
    case selectedAccessoryControl
    /// 액세서리 내부 주요 액션(종목 추가·일지 작성). `brand` 채움 + `onBrand` 라벨.
    case accessoryPrimaryAction
    /// 성과 탭 기간 세그먼트. 액세서리가 아니라 차트 바로 아래 인라인이라 glass 를 쓴다.
    case periodSegment
    /// 일지 셀·상세의 **읽기 전용** 종목 태그. 분류색을 tint 로 먹여 캡슐 자체가 "무슨 자산에
    /// 달린 기록인가" 를 말하게 한다 — 태그가 전부 같은 회색이면 이름을 읽기 전에는 구분이 안 된다.
    ///
    /// `.regular` 가 아니라 `.clear` 인 이유는 이 캡슐이 카드 **위**가 아니라 카드 **안**에
    /// 놓이기 때문이다. `.regular` 는 뒤를 흐려 카드에서 한 겹 떠 보이는데, 태그는 셀의
    /// 일부지 떠 있는 컨트롤이 아니다. `.clear` 는 흐림 없이 tint 만 남긴다.
    ///
    /// 원색이 아니라 `glassWash` 로 민 값을 먹인다. 채도를 그대로 먹이면 캡슐이 꽉 찬 색면이
    /// 되어 그 위의 `textPrimary` 가 묻힌다. 라벨 색을 분류마다 다시 고르는 대신 면을 옅게
    /// 하는 쪽을 택했다 — 라벨은 분류가 다섯이라 대비를 다섯 번 맞춰야 하지만, 면은 규칙
    /// 하나로 끝나고 라벨은 카드 면에 맞춰 둔 대비를 그대로 쓴다.
    ///
    /// 작성 폼의 **선택형** 칩은 이 역할을 쓰지 않는다 — 폼 안 컨트롤은 불투명이 규칙이라
    /// (UI 스펙 §5) 같은 분류색을 `HannunTint.wash(_:)` 로 깔아 색만 맞춘다 (`TagPill`).
    case categoryTag(AssetCategory)
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
        case .accessoryControl:
            .solid(AnyShapeStyle(Color.clear))
        case .selectedAccessoryControl:
            .solid(AnyShapeStyle(HannunTint.brandTint))
        case .accessoryPrimaryAction:
            .solid(AnyShapeStyle(Color.brand))
        case .periodSegment:
            .glass(.regular.interactive())
        case let .categoryTag(category):
            .glass(.clear.tint(category.color.glassWash))
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
            systemAccessoryStandIn
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

    /// 실제 앱에서는 시스템이 그리는 면이다. 여기서만 안쪽 컨트롤 대비를 눈으로 보려고
    /// 같은 재질을 흉내 낸다 — 앱 코드에서 이렇게 직접 얹으면 glass 가 두 겹이 된다.
    private var systemAccessoryStandIn: some View {
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
        .frame(height: Constants.systemAccessoryHeight)
        .glassEffect(.regular, in: .capsule)
    }
}

fileprivate enum Constants {
    /// 시스템 액세서리 컨테이너의 `.expanded` 높이 근사치. 프리뷰에서만 쓰는 값이라
    /// 앱 코드가 참조할 일은 없다 — 실제 높이는 시스템이 정한다.
    static let systemAccessoryHeight: CGFloat = 56
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
