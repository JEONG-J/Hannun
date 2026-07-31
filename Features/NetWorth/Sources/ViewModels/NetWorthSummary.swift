//
//  NetWorthSummary.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain

/// 전일 대비 변동. 비교할 이전 스냅샷이 없으면 만들지 않는다.
struct NetWorthChange: Equatable, Sendable {

    // MARK: - Property

    let amount: Money
    /// 0.0098 이면 +0.98%.
    let ratio: Decimal
}

/// 순자산 화면 한 벌을 그리는 데 필요한 값 묶음.
struct NetWorthSummary: Equatable, Sendable {

    // MARK: - Property

    let total: Money
    let breakdown: [CategoryBreakdown]
    /// 보유 건수. 평가금액이 0 이어도 보유가 있으면 빈 화면이 아니다.
    let holdingCount: Int
    let dailyChange: NetWorthChange?

    var isEmpty: Bool { holdingCount == 0 }

    /// 금액이 0 인 카테고리는 도넛에도 리스트에도 넣지 않는다 —
    /// 0% 섹터는 그릴 수 없고 0원 행은 읽을 정보가 없다.
    var fundedBreakdown: [CategoryBreakdown] {
        breakdown.filter { $0.amount.amount > 0 }
    }

    // MARK: - Function

    /// 담고 있는 금액을 다른 기준 통화로 옮긴다.
    ///
    /// 토글 즉시 화면을 바꾸려고 둔 경로다 (NW-2). 비중은 통화에 무관하므로 그대로 둔다.
    func converted(to currency: Currency, using rate: ExchangeRate) -> NetWorthSummary {
        guard currency != total.currency else { return self }

        return NetWorthSummary(
            total: rate.convert(total, to: currency),
            breakdown: breakdown.map {
                CategoryBreakdown(
                    category: $0.category,
                    amount: rate.convert($0.amount, to: currency),
                    weight: $0.weight
                )
            },
            holdingCount: holdingCount,
            dailyChange: dailyChange.map {
                NetWorthChange(amount: rate.convert($0.amount, to: currency), ratio: $0.ratio)
            }
        )
    }
}
