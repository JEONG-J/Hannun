//
//  BottomAccessory.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 탭바 하단 액세서리에 **담을 내용물**의 배치. `tabViewBottomAccessory(content:)` 안에 쓴다.
///
/// 배경도 높이도 직접 정하지 않는다 — 캡슐 자체는 시스템이 그린다. 시안의 떠 있는 캡슐
/// (`background_blur(20)` + shadow)은 **그 시스템 컨테이너를 그린 것**이지 그 안에 넣을 또 하나의
/// 캡슐이 아니다. 안에서 `glassEffect` 를 다시 얹으면 glass 위 glass 라 테두리가 사라져 내용이
/// 배경에 그대로 떠 있는 것처럼 보이고, 높이를 고정하면 탭바가 최소화될 때 줄어든 컨테이너와
/// 어긋난다.
///
/// 내부 컨트롤에도 glass 를 쓰지 않는다. 시스템 캡슐이 이미 반투명 면이라 그 위에 반투명을
/// 겹치면 가독성이 무너진다. `ChipGroup(appearance: .accessory)` · `AccessoryActionButton` 이
/// 이 규칙을 이미 지키고 있으므로 그대로 담으면 된다.
///
/// ## 자리는 둘이다
///
/// 왼쪽은 상태·문구, 오른쪽은 컨트롤. 폭이 모자라면 **왼쪽이 먼저 양보한다** — 오른쪽이
/// 잘리면 그 탭의 유일한 진입점이 사라지기 때문이다. `Spacer` 를 담는 쪽에서 끼워 넣던
/// 예전 방식은 이 우선순위를 표현하지 못했고 네 탭이 제각기 다른 `minLength` 를 썼다.
///
/// ```swift
/// BottomAccessory {
///     AccessoryCaption(value: "12:04", suffix: "시세 기준")
/// } trailing: {
///     CurrencyToggle(selection: $currency)
/// }
/// ```
///
/// 칩 그룹처럼 캡슐을 통째로 쓰는 내용은 한 자리짜리 이니셜라이저를 쓴다.
///
/// ## 축약은 내용이 정한다
///
/// 이 컨테이너는 시스템 placement 를 `AccessoryLayout` 으로 옮겨 `\.accessoryLayout` 으로
/// 내려보내기만 한다. 무엇을 접을지는 탭마다 달라 컨테이너가 정할 수 있는 일이 아니다 —
/// 내용 쪽에서 `@Environment(\.accessoryLayout)` 을 읽어 분기한다.
public struct BottomAccessory<Leading: View, Trailing: View>: View {

    // MARK: - Property

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessoryLayoutOverride) private var layoutOverride

    private let leading: Leading
    private let trailing: Trailing

    // MARK: - Body

    public init(
        @ViewBuilder content: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        leading = content()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: .spacingS) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .layoutPriority(Constants.trailingLayoutPriority)
        }
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity)
        .environment(\.accessoryLayout, layout)
    }

    // MARK: - Function

    /// 프리뷰가 심어 둔 강제값이 있으면 그걸 쓰고, 없으면 시스템 placement 를 옮겨 적는다.
    private var layout: AccessoryLayout {
        if let layoutOverride { return layoutOverride }
        return placement == .inline ? .inline : .expanded
    }

    /// 시스템 캡슐 안쪽 여백. 44pt 터치 타깃이 캡슐 테두리에 닿지 않을 만큼만 준다 —
    /// 바깥 여백은 시스템이 이미 넣으므로 여기서 더 벌리면 내용이 가운데로 몰린다.
    /// 축약 상태에서는 캡슐이 좁아져 1pt 도 아쉬우므로 더 붙인다.
    private var horizontalPadding: CGFloat {
        layout == .inline ? Constants.inlineHorizontalPadding : Constants.horizontalPadding
    }
}

public extension BottomAccessory where Trailing == EmptyView {
    /// 캡슐 폭을 통째로 쓰는 내용(성과 탭 벤치마크 칩) 전용.
    init(@ViewBuilder content: () -> Leading) {
        self.init(content: content, trailing: { EmptyView() })
    }
}

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = 6
    static let inlineHorizontalPadding: CGFloat = 2
    /// 폭이 모자랄 때 왼쪽 문구가 먼저 줄어들게 한다. 오른쪽 컨트롤은 고유 폭을 지킨다.
    static let trailingLayoutPriority: Double = 1
    /// 프리뷰 전용. 시스템 컨테이너 높이의 근사치다.
    static let expandedHeight: CGFloat = 56
    static let inlineHeight: CGFloat = 44
}

#if DEBUG
private struct BottomAccessoryPreview: View {

    // MARK: - Property

    private let benchmarks: [(name: String, color: Color)] = [
        ("코스피", .categoryDomestic),
        ("S&P500", .categoryForeign),
        ("나스닥", .categoryEtf),
        ("BTC", .categoryCrypto),
    ]

    private let layout: AccessoryLayout

    @State private var currency: Currency = .krw
    @State private var selectedBenchmark = "S&P500"

    // MARK: - Body

    init(layout: AccessoryLayout) {
        self.layout = layout
    }

    var body: some View {
        VStack(spacing: .spacingL) {
            standIn { netWorthAccessory }
            standIn { portfolioAccessory }
            standIn { performanceAccessory }
            standIn { journalAccessory }
        }
        .accessoryLayout(layout)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    /// 앱에서는 시스템이 그리는 캡슐. 프리뷰에는 `TabView` 가 없어 내용만 덩그러니 놓이므로
    /// 대비를 보려고 여기서만 같은 재질을 흉내 낸다 — 앱 코드에서 이렇게 감싸면 안 된다.
    private func standIn(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(height: layout == .inline ? Constants.inlineHeight : Constants.expandedHeight)
            .glassEffect(.regular, in: .capsule)
    }

    private var netWorthAccessory: some View {
        BottomAccessory {
            AccessoryCaption(value: "12:04", suffix: "시세 기준")
        } trailing: {
            CurrencyToggle(selection: $currency)
        }
    }

    private var portfolioAccessory: some View {
        BottomAccessory {
            AccessoryActionButton("종목 추가", systemImageName: "plus", style: .primary) {}
        } trailing: {
            AccessoryActionButton(
                "입출금 기록",
                systemImageName: "arrow.left.arrow.right",
                style: .secondary
            ) {}
        }
    }

    private var performanceAccessory: some View {
        BottomAccessory {
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

    private var journalAccessory: some View {
        BottomAccessory {
            AccessoryCaption("오늘의 매매를 기록해보세요")
        } trailing: {
            AccessoryActionButton("작성", systemImageName: "pencil.line") {}
        }
    }
}

#Preview("하단 액세서리 · 라이트") {
    BottomAccessoryPreview(layout: .expanded)
        .preferredColorScheme(.light)
}

#Preview("하단 액세서리 · 다크") {
    BottomAccessoryPreview(layout: .expanded)
        .preferredColorScheme(.dark)
}

#Preview("하단 액세서리 · 축약") {
    BottomAccessoryPreview(layout: .inline)
        .preferredColorScheme(.dark)
}
#endif
