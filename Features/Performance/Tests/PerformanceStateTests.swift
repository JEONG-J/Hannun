//
//  PerformanceStateTests.swift
//  PerformanceFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDesignSystem
import HannunDomain
import Testing

@testable import PerformanceFeature

@Suite("PerformanceSummary")
struct PerformanceSummaryTests {

    @Test("연초 대비 손익은 입출금을 뺀 금액이다")
    func gainExcludesCashFlow() {
        let summary = PerformanceSummary(
            YTDReturn(
                openingBalance: .krw(100_000_000),
                closingBalance: .krw(118_000_000),
                netCashFlow: .krw(8_600_000),
                rate: 0.094
            )
        )

        #expect(summary == .calculated(rate: 0.094, gain: .krw(9_400_000)))
    }

    @Test("출금이 있어도 성과만 남는다")
    func withdrawalDoesNotBecomeLoss() {
        let summary = PerformanceSummary(
            YTDReturn(
                openingBalance: .krw(100_000_000),
                closingBalance: .krw(95_000_000),
                netCashFlow: .krw(-10_000_000),
                rate: 0.05
            )
        )

        #expect(summary == .calculated(rate: 0.05, gain: .krw(5_000_000)))
    }

    @Test("계산 결과가 없으면 데이터 부족 상태가 된다")
    func missingReturnBecomesInsufficientData() {
        #expect(PerformanceSummary(nil) == .insufficientData)
    }
}

@Suite("PerformanceTrend")
struct PerformanceTrendTests {

    @Test("돌아오지 않은 지수는 비활성 목록에 남는다")
    func missingIndicesBecomeUnavailable() {
        let trend = PerformanceTrend(
            requesting: BenchmarkIndex.allCases,
            sampledPoints: PerformanceSampleData.trendPoints,
            comparison: BenchmarkComparison(
                portfolio: PerformanceSampleData.comparison.portfolio,
                benchmarks: [BenchmarkSeries(index: .sp500, points: [])]
            )
        )

        #expect(trend.unavailableIndices == [.kospi, .nasdaq, .bitcoin])
    }

    @Test("단위가 고르지 않은 시점은 차트에서 빠진다")
    func unsampledDatesAreDropped() {
        let sampled = [PerformanceSampleData.trendPoints[0], PerformanceSampleData.trendPoints[2]]

        let trend = PerformanceTrend(
            requesting: [],
            sampledPoints: sampled,
            comparison: PerformanceSampleData.comparison
        )

        #expect(trend.portfolio.map(\.date) == sampled.map(\.date))
        #expect(trend.totals.count == sampled.count)
    }
}

@Suite("수익률 플롯 값")
struct ReturnRatePlotValueTests {

    /// `Decimal` 부동소수 리터럴은 `Double` 을 거쳐 들어와 끝자리가 흔들린다
    /// (`0.094` → `9.399999999999997`). 화면은 소수 2자리까지만 쓰므로 그 자리까지만 본다.
    @Test(
        "플롯 값은 백분율 스케일이다",
        arguments: zip([Decimal(0.094), -0.0312, 0], [9.4, -3.12, 0])
    )
    func plotValueUsesPercentScale(rate: Decimal, expected: Double) {
        let plotted = AmountFormatter.percentPlotValue(ratio: rate)
        #expect(abs(plotted - expected) < Constants.plotTolerance)
    }
}

fileprivate enum Constants {
    static let plotTolerance = 0.0001
}
