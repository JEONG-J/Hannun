//
//  NetWorthSummaryTests.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore
import HannunDomain
import Testing

@testable import NetWorthFeature

@Suite("순자산 요약")
struct NetWorthSummaryTests {

    // MARK: - Property

    private let withLoan: [CategoryBreakdown] = [
        CategoryBreakdown(category: .cash, amount: .krw(4_000_000), weight: 0.4),
        CategoryBreakdown(category: .etf, amount: .krw(6_000_000), weight: 0.6),
        CategoryBreakdown(category: .loan, amount: .krw(-3_000_000), weight: 0),
    ]

    // MARK: - Function

    private func summary(_ breakdown: [CategoryBreakdown]) -> NetWorthSummary {
        NetWorthSummary(
            total: .krw(breakdown.reduce(Decimal.zero) { $0 + $1.amount.amount }),
            breakdown: breakdown,
            holdingCount: breakdown.count,
            dailyChange: nil
        )
    }

    /// 도넛 12시와 리스트 첫 줄이 가장 큰 자산군이어야 한다 (시안 §6.1).
    @Test("자산군 소계는 금액 내림차순이다")
    func sortsBreakdownByAmountDescending() {
        let result = summary([
            CategoryBreakdown(category: .cash, amount: .krw(1_000_000), weight: 0.1),
            CategoryBreakdown(category: .domesticStock, amount: .krw(3_000_000), weight: 0.3),
            CategoryBreakdown(category: .crypto, amount: .krw(6_000_000), weight: 0.6),
        ]).fundedBreakdown

        #expect(result.map(\.category) == [.crypto, .domesticStock, .cash])
    }

    @Test("금액이 같으면 자산군 선언 순서로 고정한다")
    func breaksAmountTiesByCategoryOrder() {
        let result = summary([
            CategoryBreakdown(category: .crypto, amount: .krw(1_000_000), weight: 0.25),
            CategoryBreakdown(category: .etf, amount: .krw(1_000_000), weight: 0.25),
            CategoryBreakdown(category: .cash, amount: .krw(1_000_000), weight: 0.25),
            CategoryBreakdown(category: .domesticStock, amount: .krw(1_000_000), weight: 0.25),
        ]).fundedBreakdown

        #expect(result.map(\.category) == [.cash, .domesticStock, .etf, .crypto])
    }

    @Test("금액이 0 인 자산군은 정렬 전에 빠진다")
    func dropsUnfundedCategoriesBeforeSorting() {
        let result = summary([
            CategoryBreakdown(category: .cash, amount: .krw(0), weight: 0),
            CategoryBreakdown(category: .etf, amount: .krw(2_000_000), weight: 0.4),
            CategoryBreakdown(category: .overseasStock, amount: .krw(3_000_000), weight: 0.6),
        ]).fundedBreakdown

        #expect(result.map(\.category) == [.overseasStock, .etf])
    }

    /// 통화를 바꿔도 환산은 모든 금액에 같은 비율로 걸리므로 순서가 흔들리면 안 된다.
    @Test("통화를 바꿔도 정렬이 유지된다")
    func keepsOrderAfterCurrencyConversion() {
        let converted = summary([
            CategoryBreakdown(category: .cash, amount: .krw(1_000_000), weight: 0.1),
            CategoryBreakdown(category: .etf, amount: .krw(9_000_000), weight: 0.9),
        ]).converted(to: .usd, using: ExchangeRate(krwPerUSD: 1_380))

        #expect(converted.fundedBreakdown.map(\.category) == [.etf, .cash])
    }

    @Test("대출은 도넛 배열에서 빠진다")
    func excludesLiabilityFromDonut() {
        #expect(summary(withLoan).fundedBreakdown.map(\.category) == [.etf, .cash])
    }

    /// 리스트가 히어로 총액의 검산이 되어야 한다 — 합이 다르면 화면이 스스로 거짓말을 한다.
    @Test("소계 행의 금액 합은 총액과 같다")
    func subtotalRowsSumToTotal() {
        let result = summary(withLoan)
        let sum = result.subtotalRows.reduce(Decimal.zero) { $0 + $1.amount.amount }

        #expect(sum == result.total.amount)
    }

    @Test("대출 행은 항상 마지막에 온다")
    func placesLiabilityLast() {
        #expect(summary(withLoan).subtotalRows.map(\.category) == [.etf, .cash, .loan])
    }

    @Test("전액 상환한 대출은 리스트에도 나오지 않는다")
    func dropsSettledLoan() {
        let result = summary([
            CategoryBreakdown(category: .cash, amount: .krw(4_000_000), weight: 1),
            CategoryBreakdown(category: .loan, amount: .krw(0), weight: 0),
        ]).subtotalRows

        #expect(result.map(\.category) == [.cash])
    }

    @Test("통화를 바꿔도 소계 합과 총액이 같다")
    func keepsSumAfterCurrencyConversion() {
        let converted = summary(withLoan)
            .converted(to: .usd, using: ExchangeRate(krwPerUSD: 1_000))
        let sum = converted.subtotalRows.reduce(Decimal.zero) { $0 + $1.amount.amount }

        #expect(converted.subtotalRows.map(\.category) == [.etf, .cash, .loan])
        #expect(sum == converted.total.amount)
    }
}
