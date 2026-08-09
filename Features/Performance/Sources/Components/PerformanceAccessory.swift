//
//  PerformanceAccessory.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 성과 탭 하단 액세서리 — 지금 보고 있는 값 한 줄 + 표시 단위 전환 하나
/// (PM-2, PM-3, UI 스펙 §3.1).
///
/// **캡슐 전체가 표시 단위 전환 버튼이다.** 이 탭의 액세서리에 남은 동작은 차트 **세로축**과
/// 왼쪽 문구를 `%` ↔ `₩` 로 뒤집는 것 하나뿐이라, 오른쪽 글자만 눌리게 두면 44pt 남짓한
/// 과녁 하나를 위해 나머지 캡슐이 죽는다 — 순자산·포트폴리오와 같은 문법이다. 기간·단위
/// (일별/월별)는 바꾸는 대상 옆이라 차트 카드 안이고, 벤치마크는 고르는 일도 겹치는 일도
/// 툴바 시트가 맡는다.
///
/// 그래서 오른쪽은 컨트롤이 아니라 **지금 켜진 단위를 적은 라벨**이고 알약도 테두리도 없다 —
/// 캡슐이 이미 과녁인데 그 안에 또 과녁을 그리면 "여기만 눌린다"는 거짓 신호가 된다.
/// 순자산의 통화 라벨처럼 **현재**를 적는다(왼쪽 숫자가 무슨 단위인지 말하는 자리라서다).
/// 눌러서 무엇이 되는지는 `accessibilityHint` 가 말한다 — 켜짐 채움도 `.isSelected` 도 쓰지
/// 않는 이유가 그것이다.
///
/// 왼쪽에는 `expandable()` 셰브런을 붙이지 않는다. 열리는 화면 없이 값 하나가 뒤집힐 뿐이라
/// 셰브런을 두면 "누르면 무언가 열린다"는 뜻이 되어 버린다 (UI 스펙 §3.1).
///
/// 벤치마크 범례 dot 도 여기 없다. 범례는 차트 카드 안으로 옮겨 갔으므로 액세서리가 다시
/// 말할 이유가 없다.
///
/// 왼쪽은 스크롤과 조작에 따라 말을 바꾼다. 히어로(큰 수익률)가 보이는 동안에는 **총 평가금액**을 —
/// 히어로는 수익률과 손익액만 말하므로 화면 어디에도 없는 값이다 — 히어로가 밀려 나가면
/// **지금 손으로 만지고 있는 값**부터 순서대로 말한다 (디자인 문서 §6).
///
/// 값이 아니라 ViewModel 을 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다.
struct PerformanceAccessory: View {

    /// 히어로가 밀려난 뒤 왼쪽이 말할 한 줄.
    private struct ValueCaption {

        // MARK: - Property

        let prefix: String
        let value: String
        let isLoss: Bool

        var color: Color { isLoss ? .loss : .gain }
    }

    // MARK: - Property

    @Environment(\.colorScheme) private var colorScheme

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            viewModel.toggleValueUnit()
        } label: {
            BottomAccessory {
                alternatingCaption
            } trailing: {
                valueUnitLabel
            }
            // 캡슐 높이를 다 쓰고 그 사각형 전체를 과녁으로 선언한다. 이게 없으면 히트
            // 영역이 **글자가 그려진 픽셀**로 좁아져, 캡션과 라벨 사이 빈 공간이 안 눌린다.
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            String(format: Constants.unitLabelFormat, viewModel.valueUnit.displayName)
        )
        .accessibilityHint(
            String(format: Constants.unitSwitchHintFormat, viewModel.valueUnit.toggled.displayName)
        )
        .hannunAnimation(.selection, value: viewModel.valueUnit)
    }

    // MARK: - Function

    /// 두 문구를 겹쳐 두고 투명도만 바꾼다 — 프레임이 넓은 쪽에 고정되어 교대할 때
    /// 왼쪽 폭이 널뛰지 않고, 크로스페이드도 한 번에 얻는다.
    private var alternatingCaption: some View {
        ZStack(alignment: .leading) {
            totalCaption
                .opacity(viewModel.isHeroVisible ? 1 : 0)
                .accessibilityHidden(!viewModel.isHeroVisible)

            valueCaptionView
                .opacity(viewModel.isHeroVisible ? 0 : 1)
                .accessibilityHidden(viewModel.isHeroVisible)
        }
        .hannunAnimation(.selection, value: viewModel.isHeroVisible)
    }

    /// 1대역. 기간 이름을 적던 자리인데 그 이름은 바로 위 차트 알약에도 그대로 있어 같은 값이
    /// 화면에 두 번 나왔다 (UI 스펙 §3.1). 평가금액은 히어로도 차트도 말하지 않는 값이라
    /// 겹치지 않는다. 전체 자릿수는 캡슐 폭에 안 들어가므로 억·만으로 접는다.
    ///
    /// 낼 수 없으면 아래 대역이 그대로 올라온다 — 축약 배치에서도 한 줄이라 더 줄일 것이 없다.
    @ViewBuilder
    private var totalCaption: some View {
        if let total = viewModel.latestTotal {
            AccessoryCaption(.plain(Constants.totalPrefix), .value(AmountFormatter.compact(total)))
        } else {
            valueCaptionView
        }
    }

    /// 히어로가 사라진 뒤의 2~4 대역. 계산할 값이 하나도 없으면 아무 말도 하지 않는다 —
    /// 기간 이름으로 되돌아가면 지웠던 중복이 그대로 살아난다.
    @ViewBuilder
    private var valueCaptionView: some View {
        if let caption = valueCaption {
            AccessoryCaption(.plain(caption.prefix), .accent(caption.value, caption.color))
        }
    }

    /// 지금 켜진 단위 글리프. 면도 스트로크도 두지 않고 왼쪽 캡션과 같은 한 줄 글자로 두되,
    /// 눌리는 캡슐이라는 신호는 색으로 남긴다. 다크에서 `brand` 는 4.07:1 로 AA 미달이라
    /// 잉크로 내린다 — 그 대신 다크에서는 어포던스가 위치(캡슐 오른쪽 끝)에만 남는다.
    ///
    /// 높이를 44pt 로 잡는 건 이 글자의 과녁이 아니라 **캡슐 내용의 최소 높이**를 위해서다.
    /// 누르는 자리는 캡슐 전부이고, 내용이 얇아지면 그 과녁도 같이 얇아진다.
    ///
    /// VoiceOver 에는 숨긴다. 캡슐이 하나의 버튼이고 그 값이 이미 "지금 수익률"이라
    /// 여기서 또 읽으면 "퍼센트, 지금 수익률" 이 된다.
    private var valueUnitLabel: some View {
        Text(viewModel.valueUnit.title)
            .hannunFont(.pillLabel)
            .foregroundStyle(colorScheme == .dark ? Color.textPrimary : Color.brand)
            .lineLimit(1)
            // 기본값인 `.interpolate` 는 글리프를 보간해 `%` 와 `₩` 가 겹쳐 뭉개진다.
            // 서로 무관한 글자를 섞어 봐야 얻을 게 없으므로 크로스페이드로 갈아끼운다.
            .contentTransition(.opacity)
            .frame(minHeight: .minimumTouchTarget)
            .accessibilityHidden(true)
    }

    /// 2~4 대역을 한 번에 고른다.
    ///
    /// 보고 있는 시점(스크럽·날짜 선택)이 초과수익보다 앞서는 이유는 **사용자가 지금 손으로
    /// 만지고 있는 값**이기 때문이다. 그 다음이 비교 중인 초과수익 — 겹쳐 둔 동안에는 몇 %p
    /// 이기고 있는지를 선 두 개의 간격으로 눈대중하지 않아도 된다.
    private var valueCaption: ValueCaption? {
        if let headline = viewModel.headline, headline.isFocused {
            return ValueCaption(
                prefix: Constants.focusedPrefix,
                value: AmountFormatter.compactPercentage(ratio: headline.rate),
                isLoss: headline.rate < 0
            )
        }

        if let excessReturn = viewModel.benchmarkExcessReturn,
           let index = viewModel.selectedBenchmark {
            return ValueCaption(
                prefix: String(format: Constants.excessPrefixFormat, index.title),
                value: AmountFormatter.percentagePoint(ratioDifference: excessReturn),
                isLoss: excessReturn < 0
            )
        }

        if let headline = viewModel.headline {
            return ValueCaption(
                prefix: Constants.yearToDatePrefix,
                value: AmountFormatter.compactPercentage(ratio: headline.rate),
                isLoss: headline.rate < 0
            )
        }

        return nil
    }
}

fileprivate enum Constants {
    static let totalPrefix = "총 평가금액"
    static let yearToDatePrefix = "연초 대비"
    static let focusedPrefix = "기간 시작 대비"
    static let excessPrefixFormat = "%@ 대비"
    static let unitLabelFormat = "지금 %@"
    /// "평가금액으로"·"수익률로" 는 받침이 갈려 조사를 형식에 못 박는다 — "표시로" 를 붙여
    /// 한 문장으로 맞춘다.
    static let unitSwitchHintFormat = "두 번 탭하면 %@ 표시로 바꿉니다"
}

#if DEBUG
/// 액세서리 한 줄과 그것이 무슨 상태인지를 적은 라벨.
///
/// 대역이 갈리려면 추이가 실제로 로드돼야 하므로 `.task` 를 단다. ViewModel 을 `@State` 로
/// 붙잡는 이유도 같다 — 프리뷰가 다시 그려질 때마다 새로 만들면 심어 둔 상태가 초기화된다.
private struct PerformanceAccessoryPreview: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel

    private let title: String

    // MARK: - Body

    @MainActor
    init(_ title: String, viewModel: PerformanceViewModel) {
        self.title = title
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            PerformanceAccessory(viewModel: viewModel)
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

private struct PerformanceAccessoryGallery: View {

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingL) {
                PerformanceAccessoryPreview("히어로 보이는 동안 — 총 평가금액", viewModel: .preview)

                PerformanceAccessoryPreview(
                    "금액 모드 — 컨트롤이 ₩ 로 뒤집힌다",
                    viewModel: .previewShowingAmount
                )

                PerformanceAccessoryPreview(
                    "비교 ON — 초과수익",
                    viewModel: .preview.hidingHero()
                )

                PerformanceAccessoryPreview(
                    "비교 OFF — 연초 대비",
                    viewModel: .previewWithOverlayOff.hidingHero()
                )

                PerformanceAccessoryPreview(
                    "날짜 선택 중 — 기간 시작 대비",
                    viewModel: .previewWithFocusedDate.hidingHero()
                )
            }
            .padding(.spacingL)
        }
        .background(Color.backgroundPrimary)
    }
}

#Preview("성과 액세서리 · 라이트") {
    PerformanceAccessoryGallery()
        .preferredColorScheme(.light)
}

#Preview("성과 액세서리 · 다크") {
    PerformanceAccessoryGallery()
        .preferredColorScheme(.dark)
}

#Preview("성과 액세서리 · AX5") {
    PerformanceAccessoryGallery()
        .dynamicTypeSize(.accessibility5)
}

/// 축약 캡슐에서 캡션과 컨트롤이 한 줄에 함께 들어가는지 본다. 가장 긴 대역(초과수익)으로
/// 좁은 캡슐에서도 컨트롤이 밀려나거나 문구가 잘리지 않는지 확인한다.
#Preview("성과 액세서리 · 축약") {
    PerformanceAccessoryPreview("축약", viewModel: .preview.hidingHero())
        .accessoryLayout(.inline)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
