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

/// 성과 탭 하단 액세서리 — 지금 보고 있는 값 한 줄 + 벤치마크 비교 토글 (PM-2, PM-4, UI 스펙 §3.1).
///
/// 왼쪽은 눌러서 기간 선택 시트를 여는 손잡이이자 정보 한 줄이고, 오른쪽은 고른 지수를 차트에
/// 겹칠지 끄고 켜는 토글이다. 일별/월별 세그먼트는 차트 축을 정하는 컨트롤이라 차트 카드
/// 헤더로 옮겨 갔다 — 여기 있으면 무엇을 바꾸는지 화면에서 멀어진다 (디자인 문서 §4.2 · §7).
///
/// 무엇과 비교할지(`selectedBenchmark`)는 툴바 시트가, 비교할지 말지
/// (`isBenchmarkOverlayEnabled`)는 이 토글이 맡는다. 둘을 나눠 두면 껐다 켜려고 매번 시트를
/// 열지 않아도 되고, 껐다 켜도 고른 지수가 그대로 남는다.
///
/// 벤치마크 범례 dot 은 여기 없다. 범례는 차트 카드 안으로 옮겨 갔으므로 액세서리가 다시
/// 말할 이유가 없다.
///
/// 왼쪽은 스크롤과 조작에 따라 말을 바꾼다. 히어로(큰 수익률)가 보이는 동안에는 **지금 보는
/// 기간**을, 히어로가 밀려 나가면 **지금 손으로 만지고 있는 값**부터 순서대로 말한다
/// (디자인 문서 §6).
///
/// 값이 아니라 ViewModel 을 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다.
struct PerformanceAccessory: View {

    /// 히어로가 밀려난 뒤 왼쪽이 말할 한 줄.
    ///
    /// 그리는 쪽과 `.accessibilityValue` 가 우선순위를 두 벌로 구현하면 언젠가 갈라지므로
    /// 조각을 한 번만 만들고 양쪽이 그것을 읽는다.
    private struct ValueCaption {

        // MARK: - Property

        let prefix: String
        let value: String
        let isLoss: Bool

        var color: Color { isLoss ? .loss : .gain }

        /// VoiceOver 가 읽을 한 줄. 화면에서는 두 조각이지만 귀로는 한 문장이다.
        var spoken: String { "\(prefix) \(value)" }
    }

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BottomAccessory {
            captionStrip
        } trailing: {
            // 라벨이 지수 이름 ↔ "비교" 로 갈아 끼워질 때 `.contentTransition(.opacity)` 가
            // 발화하려면 실제로 바뀌는 값에 트랜잭션이 걸려야 한다. 켜짐/꺼짐 전환은
            // `AccessoryControlButton` 이 스스로 건다.
            benchmarkToggle
                .hannunAnimation(.selection, value: viewModel.selectedBenchmark)
        }
    }

    // MARK: - Function

    /// 왼쪽 한 줄은 정보이면서 시트의 손잡이다 — 눌리는 캡션에는 `chevron.up` 을 붙여
    /// 열 것이 있다는 걸 보이게 한다 (디자인 문서 R4).
    ///
    /// `.accessibilityLabel` 을 달면 버튼이 접근성 요소 하나로 접혀 자식 `Text` 가 말하던
    /// 값이 전부 묻힌다 — 라벨은 브리프가 못 박은 문구 그대로 두고, `.accessibilityValue` 로
    /// 지금 화면이 말하는 한 줄을 가산한다.
    private var captionStrip: some View {
        Button {
            viewModel.isPeriodPickerPresented = true
        } label: {
            alternatingCaption
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Constants.pickerAccessibilityLabel)
        .accessibilityValue(captionDescription)
        .accessibilityHint(Constants.pickerAccessibilityHint)
    }

    /// 두 문구를 겹쳐 두고 투명도만 바꾼다 — 프레임이 넓은 쪽에 고정되어 교대할 때
    /// 왼쪽 폭이 널뛰지 않고, 크로스페이드도 한 번에 얻는다.
    private var alternatingCaption: some View {
        ZStack(alignment: .leading) {
            periodCaption
                .opacity(viewModel.isHeroVisible ? 1 : 0)
                .accessibilityHidden(!viewModel.isHeroVisible)

            valueCaptionView
                .opacity(viewModel.isHeroVisible ? 0 : 1)
                .accessibilityHidden(viewModel.isHeroVisible)
        }
        .hannunAnimation(.selection, value: viewModel.isHeroVisible)
    }

    /// 1대역. 단위가 차트 카드로 떠나 기간 하나만 남았으므로 축약 배치에서 더 줄일 것이 없다.
    private var periodCaption: some View {
        AccessoryCaption(viewModel.period.title)
            .expandable()
    }

    /// 히어로가 사라진 뒤의 2~4 대역. 계산할 값이 하나도 없으면 기간으로 되돌아간다.
    @ViewBuilder
    private var valueCaptionView: some View {
        if let caption = valueCaption {
            AccessoryCaption(.plain(caption.prefix), .accent(caption.value, caption.color))
                .expandable()
        } else {
            periodCaption
        }
    }

    /// 2~4 대역을 한 번에 고른다.
    ///
    /// 보고 있는 시점(스크럽·날짜 선택)이 초과수익보다 앞서는 이유는 **사용자가 지금 손으로
    /// 만지고 있는 값**이기 때문이다. 그 다음이 비교 중인 초과수익 — 토글과 짝을 이루는
    /// 정보라 켜 두면 몇 %p 이기고 있는지를 선 두 개의 간격으로 눈대중하지 않아도 된다.
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

    /// `alternatingCaption` 이 지금 그리는 대역을 말로 옮긴 것 — `.accessibilityValue` 전용.
    private var captionDescription: String {
        guard !viewModel.isHeroVisible, let caption = valueCaption else {
            return viewModel.period.title
        }

        return caption.spoken
    }

    /// 오른쪽은 고른 지수를 차트에 겹칠지 끄고 켜는 컨트롤이다. 한 대상의 두 상태이므로
    /// 선택 상태로 부호화한다 — 라벨은 **무엇과** 비교하는지를, 힌트는 누르면 무슨 일이
    /// 일어나는지를 말한다.
    ///
    /// 지수를 아직 안 골랐어도 비활성으로 두지 않는다. 그 상태에서 할 일은 정확히 하나 —
    /// 비교할 지수를 고르는 것 — 이고, 비활성 버튼은 그 하나를 막고 툴바를 찾게 만든다.
    /// 그때는 켜짐/꺼짐이 아니라 "아직 없음" 이므로 선택 부호화도 함께 뗀다.
    @ViewBuilder
    private var benchmarkToggle: some View {
        if layout == .inline {
            AccessoryControlButton(
                systemImageName: Constants.benchmarkSymbolName,
                accessibilityLabel: benchmarkAccessibilityLabel,
                isOn: isComparing,
                indicatesSelection: hasBenchmark
            ) {
                toggleComparison()
            }
            .accessibilityHint(benchmarkAccessibilityHint)
        } else {
            AccessoryControlButton(
                benchmarkTitle,
                isOn: isComparing,
                indicatesSelection: hasBenchmark,
                accessibilityLabel: benchmarkAccessibilityLabel
            ) {
                toggleComparison()
            }
            // 기본 `.interpolate` 는 "S&P500"/"비교" 글리프를 보간해 뭉갠다 — 무관한 글자를
            // 섞어 봐야 얻을 게 없으므로 크로스페이드로 갈아 끼운다.
            .contentTransition(.opacity)
            .accessibilityHint(benchmarkAccessibilityHint)
        }
    }

    private var hasBenchmark: Bool {
        viewModel.selectedBenchmark != nil
    }

    private var isComparing: Bool {
        hasBenchmark && viewModel.isBenchmarkOverlayEnabled
    }

    private var benchmarkTitle: String {
        viewModel.selectedBenchmark?.title ?? Constants.comparisonTitle
    }

    private var benchmarkAccessibilityLabel: String {
        guard let index = viewModel.selectedBenchmark else {
            return Constants.comparisonAccessibilityLabel
        }

        return "\(Constants.comparisonAccessibilityLabel), \(index.title)"
    }

    private var benchmarkAccessibilityHint: String {
        guard hasBenchmark else { return Constants.pickAccessibilityHint }

        return isComparing
            ? Constants.hideOverlayAccessibilityHint
            : Constants.showOverlayAccessibilityHint
    }

    /// 고른 지수가 없으면 겹칠 대상이 없으므로 시트를 열어 그 하나를 고르게 한다.
    private func toggleComparison() {
        guard hasBenchmark else {
            viewModel.isBenchmarkPickerPresented = true
            return
        }

        viewModel.toggleBenchmarkOverlay()
    }
}

fileprivate enum Constants {
    static let yearToDatePrefix = "연초 대비"
    static let focusedPrefix = "기간 시작 대비"
    static let excessPrefixFormat = "%@ 대비"
    static let comparisonTitle = "비교"
    static let benchmarkSymbolName = "chart.line.uptrend.xyaxis"
    static let comparisonAccessibilityLabel = "벤치마크 비교"
    static let pickAccessibilityHint = "두 번 탭하면 비교할 지수를 고릅니다"
    static let showOverlayAccessibilityHint = "두 번 탭하면 차트에 겹칩니다"
    static let hideOverlayAccessibilityHint = "두 번 탭하면 차트에서 지웁니다"
    static let pickerAccessibilityLabel = "기간"
    static let pickerAccessibilityHint = "두 번 탭하면 기간을 고를 수 있어요"
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
                PerformanceAccessoryPreview("히어로 보이는 동안 — 기간", viewModel: .preview)

                PerformanceAccessoryPreview(
                    "비교 ON — 초과수익",
                    viewModel: .preview.hidingHero()
                )

                PerformanceAccessoryPreview(
                    "비교 OFF — 연초 대비",
                    viewModel: .previewWithOverlayOff.hidingHero()
                )

                PerformanceAccessoryPreview(
                    "지수 미선택 — 누르면 시트가 열린다",
                    viewModel: .previewWithoutBenchmark.hidingHero()
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

/// 축약 배치에서는 오른쪽이 아이콘 하나로 줄어든다. 초과수익 한 줄과 함께 두어 좁은 캡슐에서
/// 왼쪽이 먼저 양보하는지 본다.
#Preview("성과 액세서리 · 축약") {
    PerformanceAccessoryPreview("축약", viewModel: .preview.hidingHero())
        .accessoryLayout(.inline)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
