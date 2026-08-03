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

/// 성과 탭 하단 액세서리 — 기간·단위 한 줄 + 단위 토글 하나 (PM-2, PM-4, UI 스펙 §3.1).
///
/// 자주 만지는 기간·단위는 여기(액세서리)에 두고, 저빈도인 벤치마크 고르기는 툴바 + 시트로
/// 내렸다. 왼쪽은 눌러서 기간 선택 시트를 여는 손잡이이자 정보 한 줄이고, 오른쪽은 일별/월별을
/// 오가는 토글이다 — 캡슐에 컨트롤이 늘어도 폭이 흔들리지 않는다 (디자인 문서 §4.2 · §7).
///
/// 벤치마크 범례 dot 은 여기 없다. 범례는 차트 카드 안으로 옮겨 갔으므로 액세서리가 다시
/// 말할 이유가 없다.
///
/// 왼쪽은 스크롤에 따라 말을 바꾼다. 히어로(큰 수익률)가 보이는 동안에는 **지금 보는
/// 기간·단위**를, 히어로가 밀려 나가면 **내 수익률이 몇 %인지**를 말한다 (디자인 문서 §6).
///
/// 값이 아니라 ViewModel 을 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다.
struct PerformanceAccessory: View {

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BottomAccessory {
            periodStrip
        } trailing: {
            granularityToggle
        }
    }

    // MARK: - Function

    /// 왼쪽 한 줄은 정보이면서 시트의 손잡이다 — 눌리는 캡션에는 `chevron.up` 을 붙여
    /// 열 것이 있다는 걸 보이게 한다 (디자인 문서 R4).
    private var periodStrip: some View {
        Button {
            viewModel.isPeriodPickerPresented = true
        } label: {
            alternatingCaption
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Constants.pickerAccessibilityLabel)
        .accessibilityHint(Constants.pickerAccessibilityHint)
    }

    /// 두 문구를 겹쳐 두고 투명도만 바꾼다 — 프레임이 넓은 쪽에 고정되어 교대할 때
    /// 왼쪽 폭이 널뛰지 않고, 크로스페이드도 한 번에 얻는다.
    private var alternatingCaption: some View {
        ZStack(alignment: .leading) {
            periodCaption
                .opacity(viewModel.isHeroVisible ? 1 : 0)
                .accessibilityHidden(!viewModel.isHeroVisible)

            headlineCaption
                .opacity(viewModel.isHeroVisible ? 0 : 1)
                .accessibilityHidden(viewModel.isHeroVisible)
        }
        .hannunAnimation(.selection, value: viewModel.isHeroVisible)
    }

    /// 히어로가 보이는 동안의 대역. 폭이 좁은 축약 배치에서는 단위까지 말할 자리가 없어
    /// 기간만 남긴다 (`NetWorthAccessory.captionSuffix` 와 같은 분기).
    private var periodCaption: some View {
        AccessoryCaption(layout == .inline ? viewModel.period.title : viewModel.periodSummary)
            .expandable()
    }

    /// 히어로가 사라진 뒤의 대역. 스크럽 중이면 그 시점 값이 그대로 따라온다.
    @ViewBuilder
    private var headlineCaption: some View {
        if let headline = viewModel.headline {
            AccessoryCaption(
                .plain(headline.isScrubbing
                    ? Constants.scrubbedHeadlinePrefix
                    : Constants.headlinePrefix),
                .accent(AmountFormatter.compactPercentage(ratio: headline.rate),
                        headline.rate < 0 ? .loss : .gain)
            )
            .expandable()
        } else {
            periodCaption
        }
    }

    /// 오른쪽은 일별/월별을 오가는 전환형 컨트롤이다. `NetWorthAccessory` 의 통화 전환과 같은
    /// 문법 — 라벨은 **지금 단위**를 말하고, 바뀔 단위는 `accessibilityHint` 가 말한다.
    /// 누를 때마다 대상이 바뀌므로 선택 상태가 아니다(`indicatesSelection: false`).
    @ViewBuilder
    private var granularityToggle: some View {
        if layout == .inline {
            AccessoryControlButton(
                systemImageName: Constants.granularityIconName,
                accessibilityLabel: granularityAccessibilityLabel,
                isOn: false,
                indicatesSelection: false
            ) {
                Task { await viewModel.toggleGranularity() }
            }
            .accessibilityHint(granularityAccessibilityHint)
        } else {
            AccessoryControlButton(
                viewModel.granularity.title,
                isOn: false,
                indicatesSelection: false,
                accessibilityLabel: granularityAccessibilityLabel
            ) {
                Task { await viewModel.toggleGranularity() }
            }
            // 기본 `.interpolate` 는 "일별"/"월별" 글리프를 보간해 뭉갠다 — 무관한 글자를
            // 섞어 봐야 얻을 게 없으므로 크로스페이드로 갈아 끼운다.
            .contentTransition(.opacity)
            .accessibilityHint(granularityAccessibilityHint)
        }
    }

    private var granularityAccessibilityLabel: String {
        String(format: Constants.granularityAccessibilityLabelFormat, viewModel.granularity.title)
    }

    private var granularityAccessibilityHint: String {
        String(format: Constants.granularityAccessibilityHintFormat, nextGranularity.title)
    }

    private var nextGranularity: TrendGranularity {
        viewModel.granularity == .daily ? .monthly : .daily
    }
}

fileprivate enum Constants {
    static let headlinePrefix = "연초 대비"
    static let scrubbedHeadlinePrefix = "기간 시작 대비"
    static let granularityIconName = "calendar"
    static let granularityAccessibilityLabelFormat = "표시 단위, 현재 %@"
    static let granularityAccessibilityHintFormat = "두 번 탭하면 %@로 바꿉니다"
    static let pickerAccessibilityLabel = "기간과 단위"
    static let pickerAccessibilityHint = "두 번 탭하면 기간을 고를 수 있어요"
}

#if DEBUG
private struct PerformanceAccessoryPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            labeled("히어로 보이는 동안 — 기간·단위") {
                PerformanceAccessory(viewModel: .preview)
            }

            labeled("히어로가 밀려 나간 뒤 — 내 수익률") {
                heroHiddenAccessory
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private var heroHiddenAccessory: some View {
        let viewModel = PerformanceViewModel.preview
        viewModel.isHeroVisible = false
        return PerformanceAccessory(viewModel: viewModel)
    }

    private func labeled(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            content()
        }
    }
}

#Preview("성과 액세서리 · 라이트") {
    PerformanceAccessoryPreview()
        .preferredColorScheme(.light)
}

#Preview("성과 액세서리 · 다크") {
    PerformanceAccessoryPreview()
        .preferredColorScheme(.dark)
}

#Preview("성과 액세서리 · AX5") {
    PerformanceAccessoryPreview()
        .dynamicTypeSize(.accessibility5)
}

#Preview("성과 액세서리 · 축약") {
    PerformanceAccessory(viewModel: .preview)
        .accessoryLayout(.inline)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
