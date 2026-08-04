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

/// 오버레이할 벤치마크 계열.
///
/// 색은 **카테고리 원색**이며 액세서리 dot 과 같은 토큰이어야 한다 — 그 dot 이 이 차트의
/// 유일한 범례다(UI 스펙 §4.3). 중립색으로 그리면 dot 이 가리키는 선이 화면에 없어진다.
/// 주선과의 위계는 색이 아니라 굵기(1pt)와 불투명도(60%)로 만든다.
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
///
/// ## 축은 시안과 다르다
///
/// 시안(§6.3)에는 0% 기준선도 Y축 라벨도 없다. 정규화 값을 그리는 이상 둘 다 없으면
/// 선 모양만 남아 "얼마나" 에 답하지 못한다 — 내려간 구간이 손실인지 고점 대비 조정인지,
/// 벤치마크와 벌어진 간격이 1%p 인지 10%p 인지 읽히지 않는다. 대신 눈금선(grid)은 긋지
/// 않아 시안의 빈 플롯을 최대한 지킨다: X축 라벨 3개, Y축 라벨 2개와 기준선 하나가 전부다.
///
/// ## 맨 윗줄은 호출부에 열려 있다
///
/// `header:` 슬롯에 넘긴 것이 범례 오른쪽에 앉는다. 차트 축을 바꾸는 컨트롤(단위 세그먼트)
/// 자리인데, 그 어휘는 Domain 개념이라 이 컴포넌트가 알아서는 안 된다 — 슬롯으로 열어 두면
/// 차트는 "맨 윗줄이 있다" 까지만 알면 된다.
public struct TrendLineChart<Header: View>: View {

    // MARK: - Property

    private let points: [TrendPoint]
    private let benchmarks: [TrendSeries]
    private let insufficientDataMessage: String
    private let header: Header
    @Binding private var selection: Date?

    @State private var scrubbedDate: Date?

    // MARK: - Body

    public init(
        points: [TrendPoint],
        benchmarks: [TrendSeries] = [],
        insufficientDataMessage: String,
        selection: Binding<Date?>,
        @ViewBuilder header: () -> Header
    ) {
        self.points = points
        self.benchmarks = benchmarks
        self.insufficientDataMessage = insufficientDataMessage
        self.header = header()
        _selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            if showsHeaderRow {
                headerRow
            }

            Group {
                if points.count > 1 {
                    chart
                } else {
                    insufficientDataNotice
                }
            }
            .frame(height: Constants.plotHeight)
        }
    }

    /// 범례와 슬롯이 한 줄을 나눠 쓴다. AX5 에서 둘이 한 줄에 안 들어가면 범례 → 슬롯
    /// 2행으로 접는다 — 어느 쪽도 줄이지 않는다. 가로 갈래에서 슬롯을 `fixedSize` 로
    /// 묶는 이유는 세그먼트가 `maxWidth: .infinity` 로 남은 폭을 다 먹어 범례를 밀어내지
    /// 않게 하기 위해서다.
    private var headerRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: .spacingM) {
                if showsLegend { legend }

                Spacer(minLength: 0)

                header
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: .spacingS) {
                if showsLegend { legend }

                header
            }
        }
    }

    /// 액세서리 leading 이 곧 기간·수익률 문구로 채워져 범례를 그릴 자리가 없어지므로 이
    /// 컴포넌트 안으로 옮겼다. 주선("내 수익률")은 화면에서 유일한 굵은 brand 선이라 넣지
    /// 않는다 — 헷갈릴 대상이 없는데 넣으면 한 줄이 두 항목으로 늘어 240pt 로 줄인 세로를
    /// 다시 먹는다.
    private var legend: some View {
        HStack(spacing: .spacingM) {
            ForEach(benchmarks) { series in
                HStack(spacing: .spacingXS) {
                    CategoryDot(color: series.color)

                    Text(series.name)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart {
            // 정규화 기준(기간 시작 = 0%). 이 선이 없으면 내려간 구간이 손실인지 고점 대비
            // 조정인지 구분되지 않는다. 데이터가 아니라 눈금이므로 점선으로 그어 실선인
            // 두 계열과 섞이지 않게 한다.
            RuleMark(y: .value(Constants.valueLabel, Constants.baselineValue))
                .foregroundStyle(Color.neutral)
                .lineStyle(
                    StrokeStyle(lineWidth: Constants.baselineWidth, dash: Constants.baselineDash)
                )

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
                // `separator` 는 흰 `surfacePrimary` 위에서 대비가 1.3:1 이라 스크럽 중인
                // 위치가 보이지 않는다. 기준선과 같은 중립색을 쓰되 실선으로 그어 —
                // 세로/실선 대 가로/점선이라 둘이 헷갈리지 않는다.
                RuleMark(x: .value(Constants.dateLabel, selectedPoint.date))
                    .foregroundStyle(Color.neutral)
                    .lineStyle(StrokeStyle(lineWidth: Constants.indicatorLineWidth))

                PointMark(
                    x: .value(Constants.dateLabel, selectedPoint.date),
                    y: .value(Constants.valueLabel, selectedPoint.value)
                )
                .foregroundStyle(Color.brand)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(
                position: .trailing,
                values: .automatic(desiredCount: Constants.yAxisLabelCount)
            ) { value in
                if let plotValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text(AmountFormatter.percentAxisLabel(plotValue: plotValue))
                            .font(.hannun(.caption, tabularFigures: true))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: Constants.xAxisLabelCount)) { _ in
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

    private var showsLegend: Bool {
        points.count > 1 && !benchmarks.isEmpty
    }

    /// 슬롯에 내용이 있으면 범례가 없어도 맨 윗줄을 그린다. 데이터가 1건 이하라 플롯 대신
    /// 안내 문구를 그리는 상태에서도 마찬가지다 — 단위를 바꾸면 점 개수가 달라질 수 있어
    /// 그 상태에서야말로 컨트롤이 필요하다.
    private var showsHeaderRow: Bool {
        showsLegend || Header.self != EmptyView.self
    }

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

public extension TrendLineChart where Header == EmptyView {
    /// 맨 윗줄에 얹을 컨트롤이 없는 호출부 전용.
    init(
        points: [TrendPoint],
        benchmarks: [TrendSeries] = [],
        insufficientDataMessage: String,
        selection: Binding<Date?>
    ) {
        self.init(
            points: points,
            benchmarks: benchmarks,
            insufficientDataMessage: insufficientDataMessage,
            selection: selection,
            header: { EmptyView() }
        )
    }
}

fileprivate enum Constants {
    static let plotHeight: CGFloat = 240
    static let primaryLineWidth: CGFloat = 2
    static let benchmarkLineWidth: CGFloat = 1
    static let indicatorLineWidth: CGFloat = 1
    static let benchmarkOpacity = 0.6
    static let areaTopOpacity = 0.3
    /// 정규화 기준. 값이 아니라 규칙이라 상수로 둔다.
    static let baselineValue = 0.0
    static let baselineWidth: CGFloat = 1
    static let baselineDash: [CGFloat] = [4, 3]
    /// 240pt 플롯에서 라벨이 붙지 않는 밀도.
    static let xAxisLabelCount = 3
    static let yAxisLabelCount = 2
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
    /// 기준선을 플롯 한가운데 두는 표본. 0% 선이 실제로 손익을 가르는지 이 케이스로 본다.
    private let losingReturns = TrendLineChartPreview.series(
        seed: [0, -1.8, 0.6, -2.4, -4.1, -1.2, -3.6, -5.2]
    )

    @State private var selection: Date?
    @State private var granularity = "일별"

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
            ) {
                SegmentedPicker(["일별", "월별"], selection: $granularity) { $0 }
            }
            .padding(.spacingL)
            .background(Color.surfacePrimary, in: .hannunContainer())

            TrendLineChart(
                points: losingReturns,
                insufficientDataMessage: "데이터가 쌓이면 추이가 표시됩니다",
                selection: $selection
            )
            .padding(.spacingL)
            .background(Color.surfacePrimary, in: .hannunContainer())

            // 점이 1건이라 플롯 대신 안내 문구가 뜨는 상태. 그 위에도 헤더 줄이 남는지 본다.
            TrendLineChart(
                points: Array(myReturns.prefix(1)),
                insufficientDataMessage: "데이터가 쌓이면 추이가 표시됩니다",
                selection: $selection
            ) {
                SegmentedPicker(["일별", "월별"], selection: $granularity) { $0 }
            }
            .padding(.spacingL)
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

/// 축 라벨이 커지면 플롯 폭이 줄어든다. 라벨끼리 겹치지 않는지 최대 사이즈로 확인한다.
#Preview("추이 차트 · AX5") {
    ScrollView { TrendLineChartPreview() }
        .background(Color.backgroundPrimary)
        .dynamicTypeSize(.accessibility5)
}
#endif
