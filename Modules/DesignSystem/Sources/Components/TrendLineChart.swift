//
//  TrendLineChart.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import Charts
import SwiftUI

/// 추이 위의 한 점. `value` 는 기간 시작을 0 으로 둔 **% 정규화 값**이다.
///
/// 금액이 아니라 정규화 값을 받는 이유는 벤치마크 오버레이 때문이다. 금액 축과 지수 값을
/// 같은 축에 겹치면 두 선의 기울기를 비교할 수 없다.
public struct TrendPoint: Identifiable, Equatable, Sendable {

    // MARK: - Property

    public let date: Date
    public let value: Double

    public var id: Date { date }

    // MARK: - Function

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// 오버레이할 벤치마크 계열. 색은 선택된 칩 색과 반드시 같아야 한다 — 칩이 곧 범례다.
public struct TrendSeries: Identifiable, Equatable, Sendable {

    // MARK: - Property

    public let id: String
    public let name: String
    public let color: Color
    public let points: [TrendPoint]

    // MARK: - Function

    public init(id: String, name: String, color: Color, points: [TrendPoint]) {
        self.id = id
        self.name = name
        self.color = color
        self.points = points
    }
}

/// 자산 추이 라인 차트. 스크럽하면 선택된 시점이 바인딩으로 올라간다.
///
/// 배경에 glass 를 깔지 않는다 — 차트는 콘텐츠지 떠 있는 기능 레이어가 아니다.
/// 불투명 `surfacePrimary` 카드 위에 얹어 쓴다.
public struct TrendLineChart: View {

    // MARK: - Property

    private let points: [TrendPoint]
    private let benchmarks: [TrendSeries]
    private let insufficientDataMessage: String
    @Binding private var selection: Date?

    @State private var scrubbedDate: Date?

    // MARK: - Body

    public init(
        points: [TrendPoint],
        benchmarks: [TrendSeries] = [],
        insufficientDataMessage: String,
        selection: Binding<Date?>
    ) {
        self.points = points
        self.benchmarks = benchmarks
        self.insufficientDataMessage = insufficientDataMessage
        _selection = selection
    }

    public var body: some View {
        Group {
            if points.count > 1 {
                chart
            } else {
                insufficientDataNotice
            }
        }
        .frame(height: Constants.plotHeight)
    }

    private var chart: some View {
        Chart {
            ForEach(benchmarks) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value(Constants.dateLabel, point.date),
                        y: .value(Constants.valueLabel, point.value),
                        series: .value(Constants.seriesLabel, series.name)
                    )
                    .foregroundStyle(series.color)
                    .lineStyle(StrokeStyle(lineWidth: Constants.benchmarkLineWidth))
                    .opacity(Constants.benchmarkOpacity)
                }
            }

            ForEach(points) { point in
                AreaMark(
                    x: .value(Constants.dateLabel, point.date),
                    y: .value(Constants.valueLabel, point.value)
                )
                .foregroundStyle(areaGradient)
            }

            ForEach(points) { point in
                LineMark(
                    x: .value(Constants.dateLabel, point.date),
                    y: .value(Constants.valueLabel, point.value),
                    series: .value(Constants.seriesLabel, Constants.primarySeriesName)
                )
                .foregroundStyle(Color.brand)
                .lineStyle(
                    StrokeStyle(lineWidth: Constants.primaryLineWidth, lineCap: .round)
                )
            }

            if let selectedPoint {
                RuleMark(x: .value(Constants.dateLabel, selectedPoint.date))
                    .foregroundStyle(Color.separator)
                    .lineStyle(StrokeStyle(lineWidth: Constants.indicatorLineWidth))

                PointMark(
                    x: .value(Constants.dateLabel, selectedPoint.date),
                    y: .value(Constants.valueLabel, selectedPoint.value)
                )
                .foregroundStyle(Color.brand)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: Constants.axisLabelCount)) { _ in
                AxisValueLabel()
                    .font(.hannun(.caption))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .chartXSelection(value: $scrubbedDate)
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: scrubbedDate) { _, newValue in
            selection = newValue.flatMap { nearestPoint(to: $0)?.date }
        }
    }

    private var insufficientDataNotice: some View {
        Text(insufficientDataMessage)
            .hannunFont(.subtext)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                .brand.opacity(Constants.areaTopOpacity),
                .brand.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Function

    private var selectedPoint: TrendPoint? {
        selection.flatMap { date in points.first { $0.date == date } }
    }

    /// 스크럽 좌표는 데이터 포인트 사이 아무 데나 떨어진다. 가장 가까운 점으로 스냅해야
    /// 상단 숫자가 실제로 존재하는 값을 보여준다.
    private func nearestPoint(to date: Date) -> TrendPoint? {
        points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}

fileprivate enum Constants {
    static let plotHeight: CGFloat = 320
    static let primaryLineWidth: CGFloat = 2
    static let benchmarkLineWidth: CGFloat = 1
    static let indicatorLineWidth: CGFloat = 1
    static let benchmarkOpacity = 0.6
    static let areaTopOpacity = 0.3
    static let axisLabelCount = 3
    static let dateLabel = "날짜"
    static let valueLabel = "수익률"
    static let seriesLabel = "계열"
    static let primarySeriesName = "내 수익률"
}

#if DEBUG
private struct TrendLineChartPreview: View {

    // MARK: - Property

    private let myReturns = TrendLineChartPreview.series(
        seed: [0, 1.2, 0.4, 3.1, 4.8, 4.2, 7.6, 9.4]
    )
    private let benchmarkReturns = TrendLineChartPreview.series(
        seed: [0, 0.8, 1.6, 1.1, 2.4, 3.6, 3.2, 5.1]
    )

    @State private var selection: Date?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("YTD 수익률 (입출금 제외)")
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                Text("+9.40%")
                    .hannunFont(.displayAmount)
                    .foregroundStyle(Color.gain)
            }

            TrendLineChart(
                points: myReturns,
                benchmarks: [
                    TrendSeries(
                        id: "sp500",
                        name: "S&P500",
                        color: .categoryForeign,
                        points: benchmarkReturns
                    ),
                ],
                insufficientDataMessage: "데이터가 쌓이면 추이가 표시됩니다",
                selection: $selection
            )
            .padding(.spacingL)
            .background(Color.surfacePrimary, in: .hannunContainer())

            TrendLineChart(
                points: Array(myReturns.prefix(1)),
                insufficientDataMessage: "데이터가 쌓이면 추이가 표시됩니다",
                selection: $selection
            )
            .background(Color.surfacePrimary, in: .hannunContainer())
        }
        .padding(.spacingL)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private static func series(seed: [Double]) -> [TrendPoint] {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        return seed.enumerated().map { offset, value in
            TrendPoint(
                date: start.addingTimeInterval(Double(offset) * 60 * 60 * 24 * 26),
                value: value
            )
        }
    }
}

#Preview("추이 차트 · 라이트") {
    ScrollView { TrendLineChartPreview() }
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("추이 차트 · 다크") {
    ScrollView { TrendLineChartPreview() }
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
