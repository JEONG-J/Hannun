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

    /// 금액이 0 인 카테고리와 부채는 넣지 않는다 — 0% 섹터도 음수 섹터도 그릴 수 없다.
    ///
    /// 금액 내림차순이라 도넛 12시에 가장 큰 자산군이 오고 리스트도 큰 것부터 읽힌다
    /// (시안 §6.1). 금액이 같으면 `AssetCategory` 선언 순서로 고정한다 — 새로고침할 때마다
    /// 섹터가 자리를 바꾸면 안 된다.
    var fundedBreakdown: [CategoryBreakdown] {
        breakdown
            .filter { !$0.category.isLiability && $0.amount.amount > 0 }
            .sorted { lhs, rhs in
                guard lhs.amount.amount == rhs.amount.amount else {
                    return lhs.amount.amount > rhs.amount.amount
                }
                return categoryOrder(lhs.category) < categoryOrder(rhs.category)
            }
    }

    /// 소계 리스트에 그릴 행. 자산군 뒤에 부채를 붙인다.
    ///
    /// **이 배열의 금액 합은 항상 `total` 과 같다** — 화면이 스스로 검산 가능해야 한다.
    /// `fundedBreakdown` 이 떨어뜨리는 나머지는 0원 카테고리뿐이라 합에 기여하지 않는다.
    var subtotalRows: [CategoryBreakdown] {
        fundedBreakdown
            + breakdown.filter { $0.category.isLiability && $0.amount.amount != 0 }
    }

    // MARK: - Function

    private func categoryOrder(_ category: AssetCategory) -> Int {
        AssetCategory.allCases.firstIndex(of: category) ?? AssetCategory.allCases.count
    }

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
