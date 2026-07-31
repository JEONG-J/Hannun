//
//  DonutChart.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import Charts
import HannunCore
import SwiftUI

/// 도넛 한 조각. 섹터 색은 카테고리 토큰에서 나오므로 리스트 dot 과 자동으로 일치한다.
public struct DonutChartSlice: Identifiable, Equatable, Sendable {

    // MARK: - Property

    public let category: AssetCategory
    public let name: String
    public let amount: Money

    public var id: AssetCategory { category }

    // MARK: - Function

    public init(category: AssetCategory, name: String, amount: Money) {
        self.category = category
        self.name = name
        self.amount = amount
    }
}

extension DonutChartSlice {
    var chartValue: Double {
        NSDecimalNumber(decimal: amount.amount.magnitude).doubleValue
    }
}

/// 자산군 비중 도넛. 중앙 홀에 총액을 두고, 섹터를 고르면 그 카테고리 값으로 바뀐다.
///
/// 섹터 내부에 퍼센트 라벨을 넣지 않고 별도 범례도 만들지 않는다 — 아래 카테고리 소계 리스트가
/// 범례이자 수치 역할을 겸한다. 그래서 도넛과 리스트는 반드시 같은 색 토큰을 봐야 한다.
public struct DonutChart: View {

    // MARK: - Property

    private let slices: [DonutChartSlice]
    private let totalLabel: String
    private let total: Money
    @Binding private var selection: AssetCategory?

    @State private var selectedAngleValue: Double?

    // MARK: - Body

    public init(
        slices: [DonutChartSlice],
        totalLabel: String,
        total: Money,
        selection: Binding<AssetCategory?>
    ) {
        self.slices = slices
        self.totalLabel = totalLabel
        self.total = total
        _selection = selection
    }

    public var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value(Constants.angleLabel, slice.chartValue),
                innerRadius: .ratio(innerRadiusRatio(for: slice)),
                outerRadius: .ratio(outerRadiusRatio(for: slice)),
                angularInset: Constants.angularInset
            )
            .foregroundStyle(slice.category.color)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngleValue)
        .frame(width: Constants.diameter, height: Constants.diameter)
        .overlay { centerHole }
        .hannunAnimation(.standard, value: selection)
        .onChange(of: selectedAngleValue) { _, newValue in
            selection = newValue.flatMap(category(atAngleValue:))
        }
    }

    private var centerHole: some View {
        VStack(spacing: .spacingXS) {
            Text(selectedSlice?.name ?? totalLabel)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            AmountText(selectedSlice?.amount ?? total, size: .row)
        }
        .lineLimit(1)
        .id(selection)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Function

    private var selectedSlice: DonutChartSlice? {
        slices.first { $0.category == selection }
    }

    /// 선택된 섹터를 1.04배로 키운다. `SectorMark` 에는 스케일이 없어 안팎 반지름을 함께 늘려
    /// 링 두께 비율을 유지한 채 확대한다 — 바깥만 늘리면 선택 섹터만 굵어져 보인다.
    private func outerRadiusRatio(for slice: DonutChartSlice) -> Double {
        slice.category == selection ? 1 : 1 / Constants.selectedSectorScale
    }

    private func innerRadiusRatio(for slice: DonutChartSlice) -> Double {
        outerRadiusRatio(for: slice) * Constants.innerRadiusRatio
    }

    private func category(atAngleValue value: Double) -> AssetCategory? {
        var upperBound = 0.0
        for slice in slices {
            upperBound += slice.chartValue
            if value <= upperBound { return slice.category }
        }
        return slices.last?.category
    }
}

fileprivate enum Constants {
    static let diameter: CGFloat = 200
    static let innerRadiusRatio = 0.62
    static let selectedSectorScale = 1.04
    static let angularInset: CGFloat = 1
    static let angleLabel = "비중"
}

#if DEBUG
private struct DonutChartPreview: View {

    // MARK: - Property

    private let slices: [DonutChartSlice] = [
        .init(category: .domesticStock, name: "국내주식", amount: .krw(43_673_000)),
        .init(category: .overseasStock, name: "해외주식", amount: .krw(33_397_000)),
        .init(category: .etf, name: "ETF", amount: .krw(23_121_000)),
        .init(category: .crypto, name: "코인", amount: .krw(15_414_000)),
        .init(category: .cash, name: "현금", amount: .krw(12_845_000)),
    ]

    @State private var selection: AssetCategory?

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingM) {
            DonutChart(
                slices: slices,
                totalLabel: "총자산",
                total: .krw(128_450_000),
                selection: $selection
            )

            VStack(spacing: .spacingS) {
                ForEach(slices) { slice in
                    HStack(spacing: .spacingXS) {
                        CategoryDot(slice.category)

                        Text(slice.name)
                            .hannunFont(.subtext)
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        AmountText(slice.amount, size: .sub)
                    }
                }
            }
        }
        .padding(.spacingM)
        .background(Color.surfacePrimary, in: .hannunContainer())
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("도넛 차트 · 라이트") {
    DonutChartPreview()
        .preferredColorScheme(.light)
}

#Preview("도넛 차트 · 다크") {
    DonutChartPreview()
        .preferredColorScheme(.dark)
}
#endif
