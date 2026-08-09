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
/// ## 자리는 둘이고, 각 자리에 하나씩만 들어간다
///
/// 왼쪽은 **주어 한 줄** — 이 탭이 지금 무엇을 보고 있는지 말하는 정보다. 오른쪽은
/// **컨트롤 하나**. 미니 플레이어와 같은 문법이고, 둘 다 늘리면 캡슐이 도구모음이 된다.
///
/// 왼쪽은 원칙적으로 눌리지 않는다. 누를 수 있는 건 **열 대상이 실제로 있을 때**뿐이고,
/// 그때는 `AccessoryCaption.expandable()` 로 셰브런을 붙여 눌린다고 말한다.
///
/// 폭이 모자라면 **왼쪽이 먼저 양보한다** — 오른쪽이 잘리면 그 탭의 유일한 진입점이
/// 사라지기 때문이다.
///
/// ```swift
/// BottomAccessory {
///     AccessoryCaption(.plain("이번 달"), .value("7건"))
/// } trailing: {
///     AccessoryActionButton("작성", systemImageName: "pencil.line") { … }
/// }
/// ```
///
/// 컨트롤이 없는 탭은 한 자리짜리 이니셜라이저를 쓴다.
///
/// ## 동작이 하나뿐이면 캡슐째 버튼으로 쓴다
///
/// 탭이 가진 동작이 하나이고 그게 **두 값을 뒤집는 것**뿐이면 — 통화든(순자산) 탭이 보여 주는
/// 면이든(포트폴리오) 차트 축의 표시 단위든(성과) — 이 컨테이너를 통째로 `Button` 라벨에
/// 넣는다. 오른쪽 글자 하나만
/// 눌리게 두면 좁은 과녁 하나를 위해 캡슐 나머지가 죽는다. 그때 오른쪽은 컨트롤이 아니라
/// **글자 라벨**이므로 알약도 테두리도 씌우지 않는다 — 캡슐 자체가 과녁인데 그 안에 또 과녁을
/// 그리면 "여기만 눌린다"는 거짓 신호가 된다. 열 대상이 여럿이거나 왼쪽·오른쪽이 서로 다른
/// 곳으로 가는 탭에는 쓸 수 없다 — 캡슐 어디를 눌러도 같은 일이 일어나야 성립한다.
///
/// 라벨에 현재 값을 적을지 눌러서 갈 곳을 적을지는 **그 자리가 무엇의 이름인지**가 정한다.
/// 순자산 오른쪽은 왼쪽 금액이 무슨 통화인지를 말하는 값이라 현재를 적고(KRW 화면에 USD 라고
/// 쓰여 있을 수는 없다), 성과 오른쪽도 같은 이유로 지금 켜진 표시 단위를 적는다. 포트폴리오
/// 오른쪽만 목적지 이름이라 갈 곳을 적는다. 어느 쪽이든 누르면 무엇이 되는지는
/// `accessibilityHint` 가 말한다.
///
/// 이건 어포던스를 새로 만드는 게 아니라 이미 있는 컨트롤의 **과녁을 캡슐 폭까지 넓히는**
/// 일이다. 그래서 확장(시트가 열리는 스트립)의 `chevron.up` 규칙과 무관하고, 글리프도 붙이지
/// 않는다 — 붙이면 누르면 무언가 열린다는 뜻이 되어 버린다.
///
/// 이때 이 컨테이너에 `.frame(maxHeight: .infinity)` 와 `.contentShape(.rect)` 를 반드시
/// 같이 건다. 버튼의 히트 영역은 라벨이 **그린 픽셀**이라, 없으면 왼쪽 문구와 오른쪽 라벨
/// 사이 빈 공간이 눌리지 않아 "캡슐 전체가 버튼"이라는 말이 절반만 사실이 된다.
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

    /// 시스템 캡슐 안쪽 여백. 문구와 컨트롤이 둥근 테두리에 붙어 보이지 않을 만큼 들여쓴다 —
    /// 바깥 여백은 시스템이 이미 넣으므로 여기서 더 벌리면 내용이 가운데로 몰린다.
    /// 축약에서는 좁아진 만큼 덜 들여쓰지만, 테두리에 닿지 않을 여백은 거기서도 지킨다 —
    /// 폭을 아끼자고 글자를 곡률까지 밀면 캡슐 밖으로 새어 나온 것처럼 읽힌다.
    private var horizontalPadding: CGFloat {
        layout == .inline ? Constants.inlineHorizontalPadding : Constants.horizontalPadding
    }
}

public extension BottomAccessory where Trailing == EmptyView {
    /// 컨트롤 없이 상태만 말하는 캡슐 전용.
    init(@ViewBuilder content: () -> Leading) {
        self.init(content: content, trailing: { EmptyView() })
    }
}

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = .spacingM
    static let inlineHorizontalPadding: CGFloat = .spacingS
    /// 폭이 모자랄 때 왼쪽 문구가 먼저 줄어들게 한다. 오른쪽 컨트롤은 고유 폭을 지킨다.
    static let trailingLayoutPriority: Double = 1
    /// 프리뷰 전용. 시스템 컨테이너 크기의 근사치다. 축약은 탭바 알약에 자리를 내주느라
    /// 확장보다 한참 좁으므로 폭까지 흉내 내야 한다 — 넓게 두면 잘림이 안 보인다.
    static let expandedHeight: CGFloat = 56
    static let inlineHeight: CGFloat = 44
    static let inlineWidth: CGFloat = 290
}

#if DEBUG
private struct BottomAccessoryPreview: View {

    // MARK: - Property

    private let layout: AccessoryLayout

    @State private var currency: Currency = .krw
    @State private var showsCashFlow = false
    @State private var showsAmountUnit = false

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
            .frame(maxWidth: layout == .inline ? Constants.inlineWidth : .infinity)
            .glassEffect(.regular, in: .capsule)
    }

    /// 캡슐째 버튼인 변형 — 오른쪽은 컨트롤이 아니라 **지금** 보고 있는 통화를 적은 라벨이다.
    private var netWorthAccessory: some View {
        Button {
            currency = currency == .krw ? .usd : .krw
        } label: {
            BottomAccessory {
                AccessoryCaption(value: "12:04", suffix: "시세 기준")
            } trailing: {
                Text(currency.rawValue)
                    .hannunFont(.pillLabel)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: .minimumTouchTarget)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// 같은 캡슐째 버튼이지만 오른쪽이 **갈 화면**의 이름이다. 두 변형을 나란히 두는 이유가
    /// 이 대비다 — 캡슐 문법은 하나인데 라벨이 가리키는 시점이 다르다.
    private var portfolioAccessory: some View {
        Button {
            showsCashFlow.toggle()
        } label: {
            BottomAccessory {
                AccessoryCaption(.value("12종목"), .plain("· 12:04 기준"))
            } trailing: {
                Label(
                    showsCashFlow ? "포트폴리오" : "입출금 기록",
                    systemImage: "arrow.left.arrow.right"
                )
                .hannunFont(.pillLabel)
                .foregroundStyle(Color.brand)
                .frame(minHeight: .minimumTouchTarget)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// 세 번째 캡슐째 버튼. 오른쪽이 통화도 갈 곳도 아닌 **지금 켜진 표시 단위** 글리프라,
    /// 라벨이 가리키는 시점이 셋 다 다르면서 문법은 하나라는 게 이 줄까지 와서 완성된다.
    /// 셰브런도 범례 dot 도 없다 — 열리는 화면이 없고 범례는 차트 카드 안으로 갔다.
    private var performanceAccessory: some View {
        Button {
            showsAmountUnit.toggle()
        } label: {
            BottomAccessory {
                AccessoryCaption(.plain("S&P500 대비"), .accent("+1.4%p", .gain))
            } trailing: {
                Text(showsAmountUnit ? "₩" : "%")
                    .hannunFont(.pillLabel)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: .minimumTouchTarget)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var journalAccessory: some View {
        BottomAccessory {
            AccessoryCaption(.plain("이번 달"), .value("7건"))
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
