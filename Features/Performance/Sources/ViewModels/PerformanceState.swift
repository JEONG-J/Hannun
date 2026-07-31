//
//  PerformanceState.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// 연초 대비 순수 투자 성과 (PM-3).
struct PerformanceSummary: Equatable, Sendable {

    // MARK: - Property

    /// 0.094 == +9.4%.
    let rate: Decimal

    /// 연초 대비 손익 금액. 입출금은 성과가 아니므로 빼고 남긴다.
    let gain: Money

    // MARK: - Function

    init(_ ytdReturn: YTDReturn) {
        rate = ytdReturn.rate
        gain = Money(
            amount: ytdReturn.closingBalance.amount
                - ytdReturn.openingBalance.amount
                - ytdReturn.netCashFlow.amount,
            currency: ytdReturn.closingBalance.currency
        )
    }
}

/// 차트가 한 번에 그릴 데이터 묶음 (PM-2, PM-4).
struct PerformanceTrend: Equatable, Sendable {

    // MARK: - Property

    /// 기간 시작을 0% 로 둔 내 수익률. 단위 토글이 고른 시점만 남는다.
    let portfolio: [BenchmarkPoint]

    /// 스크럽할 때 함께 보여줄 시점별 총자산.
    let totals: [Date: Money]

    let benchmarks: [BenchmarkSeries]

    /// 라인을 그릴 수 없어 칩을 비활성으로 표시할 지수 (PM-4 제약).
    let unavailableIndices: Set<BenchmarkIndex>

    // MARK: - Function

    /// 조회에 실패한 지수는 `CompareBenchmarkUseCase` 가 예외 없이 결과에서 빼므로,
    /// 요청한 목록에서 돌아온 목록을 뺀 나머지가 곧 실패한 지수다.
    init(
        requesting indices: [BenchmarkIndex],
        sampledPoints: [NetWorthTrendPoint],
        comparison: BenchmarkComparison
    ) {
        let sampledDates = Set(sampledPoints.map(\.date))

        portfolio = comparison.portfolio.filter { sampledDates.contains($0.date) }
        totals = Dictionary(
            sampledPoints.map { ($0.date, $0.total) },
            uniquingKeysWith: { _, latest in latest }
        )
        benchmarks = comparison.benchmarks
        unavailableIndices = Set(indices).subtracting(comparison.benchmarks.map(\.index))
    }
}

/// 상단 큰 숫자 블록이 표시할 값.
///
/// 스크럽 중에는 기준선이 연초가 아니라 **기간 시작** 으로 바뀐다 — 차트가 그 축으로 정규화돼
/// 있기 때문이다. 그래서 날짜를 함께 들고 다니며 라벨도 같이 바뀌게 한다.
struct PerformanceHeadline: Equatable, Sendable {

    // MARK: - Property

    /// 스크럽 중이면 그 시점, 아니면 nil (연초 대비).
    let scrubbedDate: Date?

    let rate: Decimal

    /// 연초 대비일 때는 손익 금액, 스크럽 중일 때는 그 시점의 총자산.
    let amount: Money?

    var isScrubbing: Bool { scrubbedDate != nil }
}
