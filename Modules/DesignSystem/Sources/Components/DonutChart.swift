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

/// 자산군 비중 도넛. 섹터를 누르면 그 카테고리의 이름과 금액이 중앙 홀에 남는다.
///
/// 섹터 내부에 퍼센트 라벨을 넣지 않고 별도 범례도 만들지 않는다 — 아래 카테고리 소계 리스트가
/// 범례이자 수치 역할을 겸한다. 그래서 도넛과 리스트는 반드시 같은 색 토큰을 봐야 한다.
///
/// 중앙 홀은 아무것도 고르지 않았을 때 총액이 아니라 **누를 수 있다는 안내**를 띄운다.
/// 총액은 히어로와 하단 액세서리가 번갈아 말하므로 (디자인 문서 §6) 여기서 한 번 더 적으면
/// 화면에서 가장 눈에 띄는 자리를 이미 있는 숫자로 채우게 된다.
public struct DonutChart: View {

    // MARK: - Property

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let slices: [DonutChartSlice]
    @Binding private var selection: AssetCategory?

    /// 손을 뗀 뒤 탭인지 스크럽인지 가른다. 스크럽이었으면 마지막으로 지나간 섹터를 남기고,
    /// 탭이었으면 같은 섹터를 다시 눌렀는지 보고 토글한다.
    @State private var isScrubbing = false

    // MARK: - Body

    public init(slices: [DonutChartSlice], selection: Binding<AssetCategory?>) {
        self.slices = slices
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
        .frame(width: Constants.diameter, height: Constants.diameter)
        .overlay { centerHole }
        .contentShape(.rect)
        .gesture(selectionGesture)
        .hannunAnimation(.standard, value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    /// 고른 섹터가 없으면 힌트, 있으면 그 카테고리의 이름과 금액.
    ///
    /// AX 사이즈에서는 심볼을 뺀다 — 홀 지름이 124pt 뿐이라 심볼과 두 줄 문구가 같이 들어가면
    /// 링을 뚫고 나간다.
    @ViewBuilder
    private var centerHole: some View {
        if let selectedSlice {
            VStack(spacing: .spacingXS) {
                Text(selectedSlice.name)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)

                AmountText(selectedSlice.amount, size: .row)
            }
            .lineLimit(1)
            .id(selectedSlice.category)
            .transition(.opacity)
        } else {
            VStack(spacing: .spacingXS) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: Constants.hintSymbolName)
                        .hannunFont(.rowTitle)
                }

                Text(Constants.hintText)
                    .hannunFont(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, .spacingS)
            .frame(maxWidth: Constants.diameter * Constants.innerRadiusRatio)
            .transition(.opacity)
        }
    }

    // MARK: - Function

    /// 탭과 스크럽을 한 제스처로 받는다.
    ///
    /// `chartAngleSelection(value:)` 을 쓰지 않는 이유는 선택의 출처가 둘이 되기 때문이다 —
    /// 같은 섹터를 다시 눌러 해제하면 프레임워크가 곧바로 같은 값을 되돌려 놓아 토글이 죽는다.
    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard value.translation.magnitude > Constants.scrubThreshold else { return }

                isScrubbing = true
                if let category = category(at: value.location) {
                    selection = category
                }
            }
            .onEnded { value in
                defer { isScrubbing = false }
                // 스크럽으로 이미 고른 섹터는 손을 떼도 남긴다.
                guard !isScrubbing else { return }

                guard let category = category(at: value.location) else { return }
                selection = selection == category ? nil : category
            }
    }

    private var selectedSlice: DonutChartSlice? {
        slices.first { $0.category == selection }
    }

    private var accessibilityValue: String {
        guard let selectedSlice else { return Constants.accessibilityEmptyValue }

        return selectedSlice.name
            + Constants.accessibilityValueSeparator
            + AmountFormatter.text(for: selectedSlice.amount)
    }

    /// 선택된 섹터를 1.04배로 키운다. `SectorMark` 에는 스케일이 없어 안팎 반지름을 함께 늘려
    /// 링 두께 비율을 유지한 채 확대한다 — 바깥만 늘리면 선택 섹터만 굵어져 보인다.
    private func outerRadiusRatio(for slice: DonutChartSlice) -> Double {
        slice.category == selection ? 1 : 1 / Constants.selectedSectorScale
    }

    private func innerRadiusRatio(for slice: DonutChartSlice) -> Double {
        outerRadiusRatio(for: slice) * Constants.innerRadiusRatio
    }

    private func category(at point: CGPoint) -> AssetCategory? {
        DonutChart.category(
            at: point,
            in: CGSize(width: Constants.diameter, height: Constants.diameter),
            slices: slices
        )
    }
}

/// 각도 판정은 뷰 상태를 보지 않는 순수 계산이라 `View` 의 메인 액터 밖에 둔다 — 그래야
/// 테스트가 액터를 끌고 오지 않는다.
extension DonutChart {
    /// 링 위의 한 점이 어느 카테고리인지.
    ///
    /// 선택 섹터 확대(`selectedSectorScale`)는 판정에 넣지 않는다 — 확대는 고른 **뒤에**
    /// 일어나므로 반영하면 같은 지점의 답이 선택 상태에 따라 달라진다.
    nonisolated static func category(
        at point: CGPoint,
        in size: CGSize,
        slices: [DonutChartSlice]
    ) -> AssetCategory? {
        let total = slices.reduce(0) { $0 + $1.chartValue }
        guard total > 0 else { return nil }

        let outerRadius = min(size.width, size.height) / 2
        let offset = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        let distance = CGPoint.zero.distance(to: offset)

        // 가운데 홀과 링 바깥은 차트가 아니다. 홀을 눌렀는데 뒤쪽 섹터가 잡히면
        // 안내 문구를 읽으려던 손이 매번 선택을 바꾼다.
        guard distance >= outerRadius * Constants.innerRadiusRatio,
              distance <= outerRadius else { return nil }

        return category(atAngleValue: total * clockwiseFraction(of: offset), slices: slices)
    }

    /// 12시에서 시계방향으로 잰 각도의 한 바퀴 대비 비율. `SectorMark` 의 기본 배치와 같다.
    nonisolated private static func clockwiseFraction(of offset: CGPoint) -> Double {
        // 화면 좌표는 y 가 아래로 자라므로 위쪽이 -y 다. 12시를 0 으로 두려면 x 와 -y 를 바꿔 넣는다.
        let radians = atan2(offset.x, -offset.y)
        let turn = 2 * Double.pi
        return (radians < 0 ? radians + turn : radians) / turn
    }

    nonisolated private static func category(
        atAngleValue value: Double,
        slices: [DonutChartSlice]
    ) -> AssetCategory? {
        var upperBound = 0.0
        for slice in slices {
            upperBound += slice.chartValue
            if value <= upperBound { return slice.category }
        }
        return slices.last?.category
    }
}

private extension CGSize {
    var magnitude: CGFloat { CGPoint.zero.distance(to: CGPoint(x: width, y: height)) }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        (pow(other.x - x, 2) + pow(other.y - y, 2)).squareRoot()
    }
}

fileprivate enum Constants {
    static let diameter: CGFloat = 200
    static let innerRadiusRatio = 0.62
    static let selectedSectorScale = 1.04
    static let angularInset: CGFloat = 1
    static let angleLabel = "비중"
    /// 이 거리를 넘겨야 스크럽으로 본다. 탭도 손가락이 몇 pt 는 흔들린다.
    static let scrubThreshold: CGFloat = 6
    static let hintSymbolName = "hand.tap"
    static let hintText = "눌러서 자산군별 보기"
    static let accessibilityLabel = "자산군 비중"
    static let accessibilityEmptyValue = "선택 안 함"
    static let accessibilityValueSeparator = ", "
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
            DonutChart(slices: slices, selection: $selection)

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
