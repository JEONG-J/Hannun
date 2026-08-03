//
//  DailyReturnTests.swift
//  HannunDomainTests
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore
import HannunTestSupport
import Testing
@testable import HannunDomain

@Suite("DailyReturn")
struct DailyReturnTests {
    private let day0 = SampleRecords.day(2026, 1, 1)
    private let day1 = SampleRecords.day(2026, 1, 2)
    private let day2 = SampleRecords.day(2026, 1, 3)

    @Test("누적 rate 가 단조 증가여도 일간 수익률은 부호가 갈린다")
    func signFlipsAcrossDays() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.10),
            BenchmarkPoint(date: day2, rate: 0.08),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day1: .krw(108_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1, day2])
        #expect(dailyReturns[0].rate > 0)
        #expect(dailyReturns[1].rate < 0)
    }

    @Test("입금한 날이 +수익으로 물들지 않는다")
    func depositDayIsNotColoredAsGain() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day1: .krw(110_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1])
        #expect(dailyReturns[0].rate == 0)
        #expect(dailyReturns[0].gain == .krw(0))
    }

    @Test("첫 점은 결과에 없다")
    func excludesOpeningPoint() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
        ]
        let totals: [Date: Money] = [day0: .krw(100_000_000)]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(!dailyReturns.map(\.date).contains(day0))
    }

    @Test("totals 에 전일이 빠져 있으면 그 날은 결과에서 빠진다")
    func skipsDayWithMissingPreviousTotal() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
            BenchmarkPoint(date: day2, rate: 0.09),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day2: .krw(120_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1])
    }

    @Test("전일 총자산이 0 이면 그 날은 결과에서 빠진다")
    func skipsDayWithZeroPreviousTotal() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
            BenchmarkPoint(date: day2, rate: 0.09),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day1: .krw(0),
            day2: .krw(120_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1])
    }

    @Test("전일 총자산의 통화가 기준과 다르면 그 날은 결과에서 빠진다")
    func skipsDayWithMismatchedCurrency() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
            BenchmarkPoint(date: day2, rate: 0.09),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day1: .usd(76_923),
            day2: .krw(120_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1])
    }

    @Test("손익 금액의 통화가 기준 통화와 같다")
    func gainCurrencyMatchesBase() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
        ]
        let totals: [Date: Money] = [
            day0: .usd(1_000),
            day1: .usd(1_100),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.first?.gain.currency == .usd)
    }

    @Test("정렬되지 않은 입력도 방어적으로 정렬해 처리한다")
    func sortsUnorderedInputDefensively() {
        let cumulative = [
            BenchmarkPoint(date: day1, rate: 0.10),
            BenchmarkPoint(date: day0, rate: 0),
        ]
        let totals: [Date: Money] = [day0: .krw(100_000_000)]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1])
        #expect(dailyReturns.first?.rate == 0.10)
    }

    @Test("빈 입력은 빈 배열을 돌려준다")
    func returnsEmptyForEmptyInput() {
        #expect(DailyReturn.series(cumulative: [], totals: [:]).isEmpty)
    }

    @Test("점 1개 입력은 빈 배열을 돌려준다")
    func returnsEmptyForSinglePoint() {
        let cumulative = [BenchmarkPoint(date: day0, rate: 0)]
        let totals: [Date: Money] = [day0: .krw(100_000_000)]

        #expect(DailyReturn.series(cumulative: cumulative, totals: totals).isEmpty)
    }

    @Test("V0 이 없으면 빈 배열을 돌려준다")
    func returnsEmptyWhenOpeningTotalMissing() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
        ]

        #expect(DailyReturn.series(cumulative: cumulative, totals: [:]).isEmpty)
    }

    @Test("V0 이 0 이하이면 빈 배열을 돌려준다")
    func returnsEmptyWhenOpeningTotalIsNotPositive() {
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
        ]
        let totals: [Date: Money] = [day0: .krw(0)]

        #expect(DailyReturn.series(cumulative: cumulative, totals: totals).isEmpty)
    }
}
