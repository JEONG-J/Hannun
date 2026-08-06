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

/// 성과 탭 하단 액세서리 — 지금 보고 있는 값 한 줄 (PM-2, PM-3, UI 스펙 §3.1).
///
/// **컨트롤이 없는 정보 전용 스트립이다.** 기간·단위는 둘 다 차트 카드 안으로 들어갔고
/// (바꾸는 대상 옆에 있어야 무엇이 달라졌는지 보인다), 벤치마크는 고르는 일도 겹치는 일도
/// 툴바 시트 한 곳이 맡는다. 남길 컨트롤이 없는데 자리를 채우려고 무언가를 두면 그게 곧
/// 도구모음의 시작이다 (`BottomAccessory` 규칙).
///
/// 그래서 왼쪽은 눌리지 않는다 — 열 대상이 없으므로 `expandable()` 셰브런도 붙이지 않는다.
/// 글리프 유무가 곧 "눌린다/안 눌린다" 신호다 (UI 스펙 §3.1).
///
/// 벤치마크 범례 dot 도 여기 없다. 범례는 차트 카드 안으로 옮겨 갔으므로 액세서리가 다시
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
    private struct ValueCaption {

        // MARK: - Property

        let prefix: String
        let value: String
        let isLoss: Bool

        var color: Color { isLoss ? .loss : .gain }
    }

    // MARK: - Property

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BottomAccessory {
            alternatingCaption
        }
    }

    // MARK: - Function

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

    /// 1대역. 기간 하나만 남았으므로 축약 배치에서 더 줄일 것이 없다.
    private var periodCaption: some View {
        AccessoryCaption(viewModel.period.title)
    }

    /// 히어로가 사라진 뒤의 2~4 대역. 계산할 값이 하나도 없으면 기간으로 되돌아간다.
    @ViewBuilder
    private var valueCaptionView: some View {
        if let caption = valueCaption {
            AccessoryCaption(.plain(caption.prefix), .accent(caption.value, caption.color))
        } else {
            periodCaption
        }
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
    static let yearToDatePrefix = "연초 대비"
    static let focusedPrefix = "기간 시작 대비"
    static let excessPrefixFormat = "%@ 대비"
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

/// 축약 캡슐에는 컨트롤이 없어 한 줄이 폭을 다 쓴다. 가장 긴 대역(초과수익)으로 좁은
/// 캡슐에서도 잘리지 않는지 본다.
#Preview("성과 액세서리 · 축약") {
    PerformanceAccessoryPreview("축약", viewModel: .preview.hidingHero())
        .accessoryLayout(.inline)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
