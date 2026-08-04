//
//  DailyReturn.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore

/// 캘린더 히트맵 한 칸에 물들일, 전일 대비 하루치 수익률.
public struct DailyReturn: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let date: Date

    /// 0.012 == 전일 대비 +1.2%.
    public let rate: Decimal

    /// 입출금을 뺀 그날의 손익 금액.
    public let gain: Money

    public var id: Date { date }

    // MARK: - Function

    public init(date: Date, rate: Decimal, gain: Money) {
        self.date = date
        self.rate = rate
        self.gain = gain
    }

    /// `CompareBenchmarkUseCase.portfolioPoints` 가 만드는 기간 시작 기준 누적 등락률을,
    /// 전일 대비 일간 수익률로 되돌린다.
    ///
    /// 저장소를 새로 조회하지 않고 이미 계산된 `cumulative` · `totals` 만 변환하는 순수 파생이라
    /// `UseCase` 를 하나 더 두지 않는다 — 두면 `CompareBenchmarkUseCase` 의 조회 파이프라인을
    /// 통째로 복제하게 된다. `FetchNetWorthTrendUseCase.firstOfEachMonth` 와 같은 결의 정적
    /// 헬퍼로 둔다.
    ///
    /// `portfolioPoints` 의 정의 `R(t) = (V(t) - V0 - F(t)) / V0` 에서
    /// `V(t) - V(t-1) - ΔF(t) = V0 · (R(t) - R(t-1))` 이 성립하므로, 입출금을 제외한 일간
    /// 손익·수익률은 누적 rate 와 총자산만으로 정확히 복원된다:
    /// `gain(t) = V0 · (R(t) − R(t−1))`, `rate(t) = gain(t) / V(t−1)`.
    ///
    /// - Parameters:
    ///   - cumulative: 날짜 오름차순을 가정하되 방어적으로 다시 정렬한다.
    ///   - totals: 같은 기간의 시점별 총자산. `cumulative` 를 정규화할 때 쓴 것과 같은
    ///     기준 통화여야 한다 — 다르면 `V0` 와 통화가 어긋나 스케일이 조용히 틀어진다.
    /// - Returns: 둘째 점부터 하나씩. 전일이 없는 첫 점은 일간 수익률을 낼 수 없어 제외한다.
    public static func series(
        cumulative: [BenchmarkPoint],
        totals: [Date: Money]
    ) -> [DailyReturn] {
        let sorted = cumulative.sorted { $0.date < $1.date }

        guard let opening = sorted.first, let openingTotal = totals[opening.date] else {
            return []
        }

        // V0 이 0 이하면 gain(t) = V0 · ΔR 이 항상 0 이거나 부호가 뒤집혀 "하루 수익률"이라는
        // 의미를 잃는다. 총자산이 없던 시점을 기준으로 삼을 수는 없으므로 V0 이 없는 경우와
        // 똑같이 빈 배열로 취급한다.
        guard openingTotal.amount > 0 else { return [] }

        var dailyReturns: [DailyReturn] = []

        for index in sorted.indices.dropFirst() {
            let previous = sorted[index - 1]
            let current = sorted[index]

            guard let previousTotal = totals[previous.date] else { continue }
            guard previousTotal.amount > 0 else { continue }
            // 다른 통화의 총자산으로 나누면 숫자가 생기긴 하지만 아무 의미도 없다 — 0 으로
            // 나누는 것과 마찬가지로 그날은 건너뛴다.
            guard previousTotal.currency == openingTotal.currency else { continue }

            let gainAmount = openingTotal.amount * (current.rate - previous.rate)

            dailyReturns.append(
                DailyReturn(
                    date: current.date,
                    rate: gainAmount / previousTotal.amount,
                    gain: Money(amount: gainAmount, currency: openingTotal.currency)
                )
            )
        }

        return dailyReturns
    }
}
