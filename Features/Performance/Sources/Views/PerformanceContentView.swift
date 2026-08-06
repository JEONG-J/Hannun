//
//  PerformanceContentView.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 성과 탭 본문 (PM-2 ~ PM-4). 위에서부터 YTD 큰 숫자 → 추이 차트 → 월간 수익률 캘린더.
///
/// 기간은 액세서리로, 벤치마크 고르기는 툴바 + 시트로 내렸다. 일별/월별만 차트 카드 헤더에
/// 둔다 — 차트 가로축을 정하는 컨트롤이라 바꾸는 대상 바로 위에 있어야 무엇이 달라지는지
/// 보인다 (UI 스펙 §4.3).
struct PerformanceContentView: View {

    // MARK: - Property

    @Environment(\.appRouter) private var appRouter

    @Bindable private var viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        _viewModel = Bindable(viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingXL) {
                if viewModel.isStale {
                    StaleBadge(message: Constants.staleMessage)
                }

                headline
                    // 히어로가 밀려 나가면 액세서리가 수익률을 대신 말한다 (디자인 문서 §6).
                    .onScrollVisibilityChange(threshold: Constants.heroVisibilityThreshold) {
                        viewModel.isHeroVisible = $0
                    }

                // 기록이 하나도 없으면 빈 상태 하나로 끝낸다. 차트 카드까지 두면 "데이터가
                // 쌓이면…" 안내가 같은 화면에 두 번 나온다. 캘린더도 같이 감춘다 — 기록이
                // 없으면 어느 달로 넘겨도 빈 격자라 넘길 이유 자체가 없다.
                if !viewModel.hasNoRecords {
                    chartCard

                    MonthlyReturnCard(viewModel: viewModel)
                }
            }
            .padding(.horizontal, .spacingL)
            .padding(.top, .spacingS)
        }
        // 기록이 없어 빈 상태 하나만 남는 화면에서는 가운데로 세운다. 차트·캘린더가 붙어
        // 뷰포트를 채우면 `.alignment` 는 쓰이지 않는다.
        .defaultScrollAnchor(viewModel.hasNoRecords ? .center : .top, for: .alignment)
        .background(Color.backgroundPrimary)
        .refreshable { await viewModel.refresh() }
        // 액세서리 캡슐이 마지막 컨트롤을 가리지 않도록 하단을 띄운다 (UI 스펙 §3.1).
        .safeAreaPadding(.bottom, .spacingXL)
    }

    @ViewBuilder
    private var headline: some View {
        switch viewModel.summaryState {
        case .idle, .loading:
            PerformanceHeadlineView(Constants.placeholderHeadline)
                .redacted(reason: .placeholder)
        case .loaded(.insufficientData):
            noRecordsState
        case .loaded(.calculated):
            if let headline = viewModel.headline {
                PerformanceHeadlineView(headline)
            }
        case let .failed(error):
            EmptyStateView(
                systemImageName: Constants.failureSymbolName,
                title: Constants.summaryFailureTitle,
                message: error.userMessage,
                actionTitle: Constants.retryTitle
            ) {
                Task { await viewModel.refresh() }
            }
        }
    }

    /// 기록이 없어 계산할 수 없는 상태는 실패가 아니다 — 다시 시도 대신 첫 종목 등록으로 보낸다.
    private var noRecordsState: some View {
        EmptyStateView(
            systemImageName: Constants.emptySymbolName,
            title: Constants.emptyTitle,
            message: Constants.emptyMessage,
            actionTitle: Constants.emptyActionTitle
        ) {
            appRouter?.navigate(to: .portfolio(category: nil))
        }
    }

    /// 차트는 콘텐츠라 glass 를 깔지 않는다 — 불투명 surface 카드 위에 얹는다 (UI 스펙 §4.3).
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            chart

            if viewModel.isScrubHintVisible {
                Text(Constants.scrubHintMessage)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
                    // 같은 안내를 차트 accessibilityHint 가 이미 말하므로 장식으로 숨긴다.
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingL)
        .hannunGlass(.contentSurface, in: .hannunContainer())
        .hannunAnimation(.selection, value: viewModel.isScrubHintVisible)
    }

    @ViewBuilder
    private var chart: some View {
        switch viewModel.trendState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacingXXL)
        case let .loaded(trend):
            TrendLineChart(
                points: plotPoints(of: trend),
                benchmarks: overlay,
                insufficientDataMessage: Constants.insufficientDataMessage,
                selection: cursorBinding
            ) {
                SegmentedPicker(TrendGranularity.allCases, selection: granularityBinding) {
                    $0.title
                }
            }
            // `.contain` 이 없으면 라벨이 서브트리 전체를 하나로 합쳐 범례의
            // `.accessibilityElement(children: .combine)` 이 통째로 삼켜진다. 컨테이너에
            // 라벨·힌트를 달고도 자식은 그대로 순회되게 하는 조합이다 (`CurrencyToggle` 과
            // 같은 패턴).
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Constants.chartAccessibilityLabel)
            .accessibilityHint(Constants.chartAccessibilityHint)
        case let .failed(error):
            EmptyStateView(
                systemImageName: Constants.failureSymbolName,
                title: Constants.trendFailureTitle,
                message: error.userMessage,
                actionTitle: Constants.retryTitle
            ) {
                Task { await viewModel.refresh() }
            }
        }
    }

    // MARK: - Function

    /// 차트 커서를 그릴 시점.
    ///
    /// 읽기와 쓰기가 서로 다른 값을 본다. 커서를 만드는 건 스크럽만이 아니라 캘린더에서 고른
    /// 날도 마찬가지라 읽을 때는 둘을 합친 `chartCursorDate`(차트가 실제로 담고 있는 점으로
    /// 스냅된 값)를 주고, 차트가 되돌려주는 값은 스크럽 자리에만 넣는다. 손을 떼 스크럽이
    /// `nil` 이 되면 읽기 쪽이 다시 캘린더 선택을 집으므로 커서가 그 자리에 남는다.
    private var cursorBinding: Binding<Date?> {
        Binding {
            viewModel.chartCursorDate
        } set: { date in
            viewModel.scrubbedDate = date
        }
    }

    /// `granularity` 는 `private(set)` 이고 바뀌면 재조회가 따라와야 하므로 세그먼트가 값을
    /// 직접 쓰지 않고 `selectGranularity(_:)` 를 부르는 계산 바인딩으로 잇는다
    /// (`BenchmarkPickerSheet` 가 겹치기 스위치를 다루는 방식과 같다).
    private var granularityBinding: Binding<TrendGranularity> {
        Binding {
            viewModel.granularity
        } set: { granularity in
            Task { await viewModel.selectGranularity(granularity) }
        }
    }

    /// 선택된 지수 하나만 겹친다. 조회에 실패한 지수는 `overlaidBenchmark` 가 이미 걸러낸다.
    private var overlay: [TrendSeries] {
        guard
            let series = viewModel.overlaidBenchmark,
            let color = viewModel.selectedBenchmark?.lineColor
        else { return [] }

        return [
            TrendSeries(
                id: series.index.rawValue,
                name: series.index.title,
                color: color,
                points: series.points.map(plotPoint)
            ),
        ]
    }

    private func plotPoints(of trend: PerformanceTrend) -> [TrendPoint] {
        trend.portfolio.map(plotPoint)
    }

    private func plotPoint(_ point: BenchmarkPoint) -> TrendPoint {
        TrendPoint(date: point.date, value: AmountFormatter.percentPlotValue(ratio: point.rate))
    }
}

fileprivate enum Constants {
    static let placeholderHeadline = PerformanceHeadline(
        focusedDate: nil,
        rate: 0,
        amount: .krw(0)
    )
    static let staleMessage = "갱신 실패 · 마지막으로 받아온 값입니다"
    static let insufficientDataMessage = "데이터가 쌓이면 추이가 표시됩니다"
    static let emptySymbolName = "chart.line.uptrend.xyaxis"
    static let emptyTitle = "아직 계산할 성과가 없어요"
    static let emptyMessage = "보유 종목을 등록하면 연초 대비 수익률을 볼 수 있어요."
    static let emptyActionTitle = "종목 추가"
    static let summaryFailureTitle = "수익률을 계산하지 못했어요"
    static let trendFailureTitle = "추이를 불러오지 못했어요"
    static let retryTitle = "다시 시도"
    static let failureSymbolName = "exclamationmark.triangle"
    static let chartAccessibilityLabel = "자산 추이 차트"
    static let chartAccessibilityHint = "좌우로 쓸면 시점별 수익률을 읽어 줍니다"
    static let scrubHintMessage = "차트를 좌우로 쓸어 시점별 수익률을 볼 수 있어요"
    /// 히어로가 거의 다 밀려 나간 뒤에 교대한다 — 살짝 걸쳐 있을 때 바뀌면 같은 숫자가
    /// 위아래에 동시에 보인다.
    static let heroVisibilityThreshold: Double = 0.1
}

#if DEBUG
private struct PerformanceContentPreview: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel

    // MARK: - Body

    @MainActor
    init(viewModel: PerformanceViewModel = .preview) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            PerformanceContentView(viewModel: viewModel)
                .navigationTitle("투자 성과")
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

#Preview("성과 본문 · 라이트") {
    PerformanceContentPreview()
        .preferredColorScheme(.light)
}

#Preview("성과 본문 · 다크") {
    PerformanceContentPreview()
        .preferredColorScheme(.dark)
}

#Preview("성과 본문 · 기록 없음") {
    PerformanceContentPreview(viewModel: .previewWithoutRecords)
}

/// 지수를 겹친 채 차트 위 한 점을 고른 상태. 히어로가 그 시점 값으로 바뀌고 같은 자리에
/// 커서가 서는지 본다.
#Preview("성과 본문 · 비교 ON + 날짜 선택") {
    PerformanceContentPreview(viewModel: .previewWithFocusedDate)
}
#endif
