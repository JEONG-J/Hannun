//
//  BenchmarkAccessory.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 성과 탭 하단 액세서리 — 비교 한 줄 + 비교 on/off 하나 (PM-4, UI 스펙 §3.1).
///
/// 예전에는 지수 칩 4개를 늘어놓고 폭이 모자라면 Menu 로 접었다. 칩 넷은 "지금 무엇과
/// 비교하고 있는지"를 말해 주지 않았고(넷 다 같은 크기로 나열될 뿐이다) 접히는 순간
/// 문법도 바뀌었다. 지금은 왼쪽이 **결과 한 줄**을 말하고, 고르는 일은 그 줄을 눌러 여는
/// 시트가 맡는다 — 선택지가 늘어도 캡슐 폭이 흔들리지 않는다 (디자인 문서 §4.2 · §7).
///
/// 왼쪽은 스크롤에 따라 말을 바꾼다. 히어로(큰 수익률)가 보이는 동안에는 **지수 대비 몇
/// %p 인지**를, 히어로가 밀려 나가면 **내 수익률이 몇 %인지**를 말한다 (디자인 문서 §6).
///
/// 값이 아니라 ViewModel 을 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다.
struct BenchmarkAccessory: View {

    // MARK: - Property

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BottomAccessory {
            comparisonStrip
        } trailing: {
            overlayToggle
        }
    }

    // MARK: - Function

    /// 왼쪽 한 줄은 정보이면서 시트의 손잡이다 — 눌리는 캡션에는 `chevron.up` 을 붙여
    /// 열 것이 있다는 걸 보이게 한다 (디자인 문서 R4).
    private var comparisonStrip: some View {
        Button {
            viewModel.isBenchmarkPickerPresented = true
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
            benchmarkCaption
                .opacity(viewModel.isHeroVisible ? 1 : 0)
                .accessibilityHidden(!viewModel.isHeroVisible)

            headlineCaption
                .opacity(viewModel.isHeroVisible ? 0 : 1)
                .accessibilityHidden(viewModel.isHeroVisible)
        }
        .hannunAnimation(.selection, value: viewModel.isHeroVisible)
    }

    /// 고른 지수가 없으면 고르라고 하고, 골랐는데 아직 겹칠 값이 없으면 이름만 말한다.
    /// 초과수익은 두 라인이 다 있을 때만 계산되므로 그때만 숫자를 붙인다.
    ///
    /// 세 분기 모두 dot 을 단다 — 미선택 분기에서만 빼면 지수를 고르는 순간 문구 전체가
    /// dot 폭만큼 밀린다 (UI 스펙 §4.3 "dot 은 상시 배치").
    @ViewBuilder
    private var benchmarkCaption: some View {
        if let index = viewModel.selectedBenchmark {
            if let excess = viewModel.benchmarkExcessReturn {
                AccessoryCaption(
                    .plain(index.title + Constants.comparisonSuffix),
                    .accent(AmountFormatter.percentagePoint(ratioDifference: excess),
                            excess < 0 ? .loss : .gain)
                )
                .dotted(legendColor)
                .expandable()
            } else {
                AccessoryCaption(.plain(index.title))
                    .dotted(legendColor)
                    .expandable()
            }
        } else {
            AccessoryCaption(Constants.emptySelectionCaption)
                .dotted(legendColor)
                .expandable()
        }
    }

    /// dot 은 차트 위 벤치마크 라인의 **유일한 범례**다. 그래서 실제로 겹쳐져 있을 때만
    /// 카테고리 원색이고, 비교를 끄거나 아직 아무것도 고르지 않았으면 중립으로 내린다 —
    /// 겹치지 않은 상태에서 원색이면 화면에 없는 선을 가리키는 거짓 범례가 된다 (UI 스펙 §4.3).
    private var legendColor: Color {
        guard
            viewModel.isBenchmarkOverlayEnabled,
            let index = viewModel.selectedBenchmark
        else { return .neutral }

        return index.lineColor
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
            benchmarkCaption
        }
    }

    /// 오른쪽은 상태 컨트롤이다 — 켜짐/꺼짐이 있는 하나이므로 켜짐은 채움, 꺼짐은 1pt
    /// 스트로크로 그린다 (디자인 문서 §3.2). 고른 지수가 없을 때 누르면 선택 시트가 열린다.
    private var overlayToggle: some View {
        AccessoryControlButton(
            Constants.overlayToggleTitle,
            isOn: viewModel.isBenchmarkOverlayEnabled,
            accessibilityLabel: Constants.overlayToggleAccessibilityLabel
        ) {
            viewModel.toggleBenchmarkOverlay()
        }
    }
}

fileprivate enum Constants {
    static let comparisonSuffix = " 대비"
    static let emptySelectionCaption = "벤치마크 선택"
    static let headlinePrefix = "연초 대비"
    static let scrubbedHeadlinePrefix = "기간 시작 대비"
    static let overlayToggleTitle = "비교"
    static let overlayToggleAccessibilityLabel = "벤치마크 비교"
    static let pickerAccessibilityLabel = "비교 벤치마크"
    static let pickerAccessibilityHint = "두 번 탭하면 지수를 고를 수 있어요"
}

#if DEBUG
/// 범례 dot 의 세 상태를 한 화면에 세워 둔다 — 위아래로 훑으면 dot 이 자리를 지키는지,
/// 비교를 껐을 때만 색이 빠지는지 한눈에 보인다.
private struct BenchmarkAccessoryPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            labeled("비교 ON — 카테고리 원색") {
                BenchmarkAccessory(viewModel: .preview)
            }

            labeled("비교 OFF — 중립") {
                BenchmarkAccessory(viewModel: .previewWithOverlayOff)
            }

            labeled("미선택 — 중립, dot 자리 유지") {
                BenchmarkAccessory(viewModel: .previewWithoutBenchmark)
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

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

#Preview("벤치마크 액세서리 · 라이트") {
    BenchmarkAccessoryPreview()
        .preferredColorScheme(.light)
}

#Preview("벤치마크 액세서리 · 다크") {
    BenchmarkAccessoryPreview()
        .preferredColorScheme(.dark)
}

#Preview("벤치마크 액세서리 · AX5") {
    BenchmarkAccessoryPreview()
        .dynamicTypeSize(.accessibility5)
}

#Preview("벤치마크 액세서리 · 축약") {
    BenchmarkAccessory(viewModel: .preview)
        .accessoryLayout(.inline)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
