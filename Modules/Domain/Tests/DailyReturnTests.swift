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
            day1: .krw(125_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1, day2])
        #expect(dailyReturns[0].rate > 0)
        #expect(dailyReturns[1].rate < 0)

        // 부호만으로는 `gain = V(t-1)·ΔR`(V0 대신 전일 총자산으로 스케일) 이나
        // `rate = gain/V0`(분모를 V0 으로) 같은 그럴듯한 오답도 구별하지 못한다. 정확한 값을
        // 못박아 둘 다 잡아낸다 — 오답이면 각각 -2_500_000, -0.02 가 나온다.
        #expect(dailyReturns[1].gain == .krw(-2_000_000))
        #expect(dailyReturns[1].rate == -0.016)
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

        #expect(dailyReturns.map(\.date) == [day1])
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
        #expect(dailyReturns.first?.gain.currency == .krw)
    }

    // `previousTotal.currency == openingTotal.currency` 가드(`DailyReturn.swift`) 때문에
    // 여기 남는 통화 쌍은 항상 같다 — 이 테스트는 브리프 문구를 문자로 충족할 뿐, 통화가
    // 갈리는 두 후보 중 실제로 무엇이 쓰였는지는 가려내지 못한다. 그 판별은
    // `skipsDayWithMismatchedCurrency` 가 맡는다.
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

    @Test("앱을 안 켠 날은 결과에서 빠지고, 다시 켠 날이 그동안의 등락을 받는다")
    func skipsCarriedForwardDays() {
        // day1 은 day0 값을 그대로 옮겨 적은 날이라 누적 rate 가 day0 과 같다.
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0),
            BenchmarkPoint(date: day2, rate: -0.05),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day1: .krw(100_000_000),
            day2: .krw(95_000_000),
        ]

        let dailyReturns = DailyReturn.series(
            cumulative: cumulative,
            totals: totals,
            carriedForwardDates: [day1]
        )

        #expect(dailyReturns.map(\.date) == [day2])
        // 빠진 하루의 등락이 사라지지 않고 앱을 다시 켠 날로 모인다.
        #expect(dailyReturns[0].gain == .krw(-5_000_000))
        #expect(dailyReturns[0].rate == -0.05)
    }

    @Test("실제로 안 움직인 날은 그대로 0 으로 남는다")
    func keepsGenuineFlatDay() {
        // 위 테스트와 입력이 같고 `carriedForwardDates` 만 비었다 — 두 상태가 표식 하나로만
        // 갈린다는 것, 즉 값으로는 구별할 수 없다는 것이 이 이슈의 요지다.
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0),
        ]
        let totals: [Date: Money] = [
            day0: .krw(100_000_000),
            day1: .krw(100_000_000),
        ]

        let dailyReturns = DailyReturn.series(cumulative: cumulative, totals: totals)

        #expect(dailyReturns.map(\.date) == [day1])
        #expect(dailyReturns[0].rate == 0)
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
        // 2점 입력이면 `previous` 가 곧 opening point 라 일별 가드(전일 총자산 > 0)가 이미
        // 유일한 후보일을 걸러내, V0 가드를 지워도 이 테스트가 통과해 버린다. V0 가드가
        // 실제로 걸러내는 3번째 점을 둬야 두 가드가 구별된다.
        let cumulative = [
            BenchmarkPoint(date: day0, rate: 0),
            BenchmarkPoint(date: day1, rate: 0.05),
            BenchmarkPoint(date: day2, rate: 0.09),
        ]
        let totals: [Date: Money] = [
            day0: .krw(0),
            day1: .krw(100_000_000),
        ]

        #expect(DailyReturn.series(cumulative: cumulative, totals: totals).isEmpty)
    }
}
