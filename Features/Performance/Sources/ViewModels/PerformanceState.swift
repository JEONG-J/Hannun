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
///
/// 계산할 기록이 아직 없는 상태를 값으로 들고 있는다 — 첫 기록을 기다리는 정상 상태라
/// `Loadable.failed` 로 보내면 저장소 오류와 구분되지 않기 때문이다.
enum PerformanceSummary: Equatable, Sendable {

    /// 기준 삼을 연초 자산이 없어 아직 수익률을 낼 수 없는 상태.
    case insufficientData

    /// `rate` 는 0.094 == +9.4%, `gain` 은 입출금을 뺀 연초 대비 손익 금액.
    case calculated(rate: Decimal, gain: Money)

    // MARK: - Function

    init(_ ytdReturn: YTDReturn?) {
        guard let ytdReturn else {
            self = .insufficientData
            return
        }

        self = .calculated(
            rate: ytdReturn.rate,
            gain: Money(
                amount: ytdReturn.closingBalance.amount
                    - ytdReturn.openingBalance.amount
                    - ytdReturn.netCashFlow.amount,
                currency: ytdReturn.closingBalance.currency
            )
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
/// 특정 시점을 보고 있을 때는 기준선이 연초가 아니라 **기간 시작** 으로 바뀐다 — 차트가 그
/// 축으로 정규화돼 있기 때문이다. 그래서 날짜를 함께 들고 다니며 라벨도 같이 바뀌게 한다.
///
/// 그 시점이 스크럽에서 왔는지 캘린더 선택에서 왔는지는 여기서 구분하지 않는다. 기준선이
/// 양쪽 모두 기간 시작이라 문장이 같고, 출처를 구분해 봐야 쓸 데가 없다.
struct PerformanceHeadline: Equatable, Sendable {

    // MARK: - Property

    /// 보고 있는 시점, 없으면 nil (연초 대비).
    let focusedDate: Date?

    let rate: Decimal

    /// 연초 대비일 때는 손익 금액, 특정 시점을 볼 때는 그 시점의 총자산.
    let amount: Money?

    var isFocused: Bool { focusedDate != nil }
}
