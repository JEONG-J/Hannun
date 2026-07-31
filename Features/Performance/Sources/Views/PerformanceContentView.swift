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

/// 성과 탭 본문 (PM-2 ~ PM-4). 위에서부터 YTD 큰 숫자 → 추이 차트 → 단위·기간 컨트롤.
struct PerformanceContentView: View {

    // MARK: - Property

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
                chartCard
                controls
            }
            .padding(.horizontal, .spacingL)
            .padding(.top, .spacingS)
        }
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
        case .loaded:
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

    /// 차트는 콘텐츠라 glass 를 깔지 않는다 — 불투명 surface 카드 위에 얹는다 (UI 스펙 §4.3).
    private var chartCard: some View {
        chart
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacingL)
            .hannunGlass(.contentSurface, in: .hannunContainer())
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
                selection: $viewModel.scrubbedDate
            )
            .accessibilityLabel(Constants.chartAccessibilityLabel)
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

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: .spacingM) {
                GranularityToggle(selection: granularity)
                Spacer(minLength: .spacingS)
                PeriodSegment(selection: period)
            }

            VStack(alignment: .leading, spacing: .spacingM) {
                GranularityToggle(selection: granularity)
                PeriodSegment(selection: period)
            }
        }
    }

    // MARK: - Function

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

    private var granularity: Binding<TrendGranularity> {
        Binding(
            get: { viewModel.granularity },
            set: { newValue in Task { await viewModel.selectGranularity(newValue) } }
        )
    }

    private var period: Binding<ChartPeriod> {
        Binding(
            get: { viewModel.period },
            set: { newValue in Task { await viewModel.selectPeriod(newValue) } }
        )
    }

    private func plotPoints(of trend: PerformanceTrend) -> [TrendPoint] {
        trend.portfolio.map(plotPoint)
    }

    private func plotPoint(_ point: BenchmarkPoint) -> TrendPoint {
        TrendPoint(date: point.date, value: ReturnRate.plotValue(point.rate))
    }
}

fileprivate enum Constants {
    static let placeholderHeadline = PerformanceHeadline(
        scrubbedDate: nil,
        rate: 0,
        amount: .krw(0)
    )
    static let staleMessage = "갱신 실패 · 마지막으로 받아온 값입니다"
    static let insufficientDataMessage = "데이터가 쌓이면 추이가 표시됩니다"
    static let summaryFailureTitle = "수익률을 계산하지 못했어요"
    static let trendFailureTitle = "추이를 불러오지 못했어요"
    static let retryTitle = "다시 시도"
    static let failureSymbolName = "exclamationmark.triangle"
    static let chartAccessibilityLabel = "자산 추이 차트. 좌우로 쓸어 시점별 수익률을 확인할 수 있어요."
}

#if DEBUG
private struct PerformanceContentPreview: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel

    // MARK: - Body

    @MainActor
    init() {
        _viewModel = State(initialValue: .preview)
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
#endif
