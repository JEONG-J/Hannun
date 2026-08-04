//
//  CalendarHeatmapTests.swift
//  HannunDesignSystemTests
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import Testing
@testable import HannunDesignSystem

@Suite("CalendarHeatmap 채움 불투명도 단계")
struct CalendarHeatmapFillOpacityTests {

    @Test("절대값이 0.005 미만이면 0.20 이다 — 0(변동 없음)도 이 단계다")
    func lowTierIncludesZeroAndItsUpperEdge() {
        #expect(CalendarHeatmap.fillOpacity(ratioMagnitude: 0) == 0.20)
        #expect(CalendarHeatmap.fillOpacity(ratioMagnitude: 0.0049) == 0.20)
    }

    @Test("정확히 0.005 는 다음 단계(0.40)로 넘어간다 — 경계는 포함하지 않는 쪽이 다음 단계다")
    func midTierStartsAtItsLowerBoundInclusive() {
        #expect(CalendarHeatmap.fillOpacity(ratioMagnitude: 0.005) == 0.40)
        #expect(CalendarHeatmap.fillOpacity(ratioMagnitude: 0.019) == 0.40)
    }

    @Test("정확히 0.02 는 다음 단계(0.60)로 넘어간다")
    func highTierStartsAtItsLowerBoundInclusive() {
        #expect(CalendarHeatmap.fillOpacity(ratioMagnitude: 0.02) == 0.60)
        #expect(CalendarHeatmap.fillOpacity(ratioMagnitude: 0.05) == 0.60)
    }

    /// `fillOpacity` 는 절대값을 받으므로, 손실 쪽 `ratio.magnitude` 를 그대로 흘려보내도
    /// 이익 쪽과 같은 경계에서 단계가 갈려야 한다.
    @Test("손실 비율도 magnitude 를 거치면 이익과 같은 경계에서 단계가 갈린다")
    func negativeRatioMagnitudeMirrorsPositiveTiers() {
        let boundaries: [(ratio: Decimal, expectedOpacity: Double)] = [
            (-0.0049, 0.20), (-0.005, 0.40), (-0.019, 0.40), (-0.02, 0.60), (-0.05, 0.60),
        ]
        for boundary in boundaries {
            let opacity = CalendarHeatmap.fillOpacity(ratioMagnitude: boundary.ratio.magnitude)
            #expect(opacity == boundary.expectedOpacity)
        }
    }
}

@Suite("CalendarHeatmap 앞자리 빈 칸 수")
struct CalendarHeatmapLeadingBlankCountTests {

    /// 2026년 8월 1일은 토요일(그레고리력 요일 번호 7), 2027년 1월 1일은 금요일(6)이다 —
    /// 1일의 요일이 서로 다른 두 달로 `firstWeekday` 별 계산을 검증한다.
    @Test("일요일 시작(firstWeekday 1) — 토요일 1일은 앞에 6칸이 빈다")
    func sundayStartCountsSixBlanksBeforeSaturdayFirst() {
        let calendar = CalendarHeatmapLeadingBlankCountTests.utcCalendar(firstWeekday: 1)
        let month = CalendarHeatmapLeadingBlankCountTests.firstOfMonth(2026, 8)

        #expect(CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar) == 6)
    }

    @Test("월요일 시작(firstWeekday 2) — 같은 토요일 1일은 앞에 5칸만 빈다")
    func mondayStartCountsFiveBlanksBeforeSameSaturdayFirst() {
        let calendar = CalendarHeatmapLeadingBlankCountTests.utcCalendar(firstWeekday: 2)
        let month = CalendarHeatmapLeadingBlankCountTests.firstOfMonth(2026, 8)

        #expect(CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar) == 5)
    }

    @Test("일요일 시작 — 금요일 1일은 앞에 5칸이 빈다")
    func sundayStartCountsFiveBlanksBeforeFridayFirst() {
        let calendar = CalendarHeatmapLeadingBlankCountTests.utcCalendar(firstWeekday: 1)
        let month = CalendarHeatmapLeadingBlankCountTests.firstOfMonth(2027, 1)

        #expect(CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar) == 5)
    }

    @Test("월요일 시작 — 같은 금요일 1일은 앞에 4칸만 빈다")
    func mondayStartCountsFourBlanksBeforeSameFridayFirst() {
        let calendar = CalendarHeatmapLeadingBlankCountTests.utcCalendar(firstWeekday: 2)
        let month = CalendarHeatmapLeadingBlankCountTests.firstOfMonth(2027, 1)

        #expect(CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar) == 4)
    }

    /// `+ Constants.daysPerWeek` 되감기 항이 없으면 이 두 케이스에서 음수가 나와
    /// `gridDays` 의 `Array(repeating:count:)` 가 런타임 트랩을 낸다 — 위 네 케이스는
    /// 전부 `weekday > firstWeekday` 라 되감기 항이 빠져도 우연히 통과한다.
    @Test("토요일 시작(firstWeekday 7) — 토요일 1일은 곧 시작 요일이라 앞에 0칸이 빈다")
    func saturdayStartCountsZeroBlanksBeforeSaturdayFirst() {
        let calendar = CalendarHeatmapLeadingBlankCountTests.utcCalendar(firstWeekday: 7)
        let month = CalendarHeatmapLeadingBlankCountTests.firstOfMonth(2026, 8)

        #expect(CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar) == 0)
    }

    @Test("토요일 시작 — 일요일 1일은 되감겨 앞에 1칸만 빈다")
    func saturdayStartWrapsAroundBeforeSundayFirst() {
        let calendar = CalendarHeatmapLeadingBlankCountTests.utcCalendar(firstWeekday: 7)
        let month = CalendarHeatmapLeadingBlankCountTests.firstOfMonth(2026, 11)

        #expect(CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar) == 1)
    }

    /// 호스트 타임존이 달라도 "그 달 1일" 이 하루 밀리지 않도록 UTC 로 고정한다.
    private static func utcCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private static func firstOfMonth(_ year: Int, _ month: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }
}

@Suite("CalendarHeatmap 그리드 날짜")
struct CalendarHeatmapGridDaysTests {

    @Test(
        "그리드 총 길이는 항상 7의 배수다",
        arguments: [
            (year: 2026, month: 8, firstWeekday: 1),
            (year: 2026, month: 8, firstWeekday: 7),
            (year: 2026, month: 11, firstWeekday: 7),
            (year: 2027, month: 2, firstWeekday: 2),
            (year: 2028, month: 2, firstWeekday: 1),
        ]
    )
    func totalLengthIsAlwaysMultipleOfSeven(
        fixture: (year: Int, month: Int, firstWeekday: Int)
    ) {
        let calendar = CalendarHeatmapGridDaysTests.utcCalendar(firstWeekday: fixture.firstWeekday)
        let month = CalendarHeatmapGridDaysTests.firstOfMonth(fixture.year, fixture.month)

        let days = CalendarHeatmap.gridDays(month: month, calendar: calendar)

        #expect(days.count % 7 == 0)
    }

    @Test("평년 2월은 28칸이 채워진다 — 2027년")
    func nonLeapFebruaryFillsTwentyEightDays() {
        let calendar = CalendarHeatmapGridDaysTests.utcCalendar(firstWeekday: 1)
        let month = CalendarHeatmapGridDaysTests.firstOfMonth(2027, 2)

        let days = CalendarHeatmap.gridDays(month: month, calendar: calendar)

        #expect(days.compactMap { $0 }.count == 28)
    }

    @Test("윤년 2월은 29칸이 채워진다 — 2028년")
    func leapFebruaryFillsTwentyNineDays() {
        let calendar = CalendarHeatmapGridDaysTests.utcCalendar(firstWeekday: 1)
        let month = CalendarHeatmapGridDaysTests.firstOfMonth(2028, 2)

        let days = CalendarHeatmap.gridDays(month: month, calendar: calendar)

        #expect(days.compactMap { $0 }.count == 29)
    }

    /// 앞칸 개수는 `leadingBlankCount` 와 독립적으로 일치해야 하고, 뒷칸 개수는
    /// "앞칸 + 채운 날짜를 7로 나눈 나머지를 채우는 최소값" 이라는 별도 공식으로 다시
    /// 계산해도 같아야 한다 — 셋 중 하나만 어긋나도 총 길이는 우연히 7의 배수를 유지할 수
    /// 있어서, 총 길이 테스트만으로는 날짜가 엉뚱한 칸에 앉는 걸 잡지 못한다.
    @Test("앞칸·채운 날짜·뒷칸 개수가 독립 계산과 정확히 맞아떨어진다")
    func leadingFilledAndTrailingCountsMatchIndependentCalculation() {
        let calendar = CalendarHeatmapGridDaysTests.utcCalendar(firstWeekday: 2)
        let month = CalendarHeatmapGridDaysTests.firstOfMonth(2026, 8)

        let days = CalendarHeatmap.gridDays(month: month, calendar: calendar)
        let leading = CalendarHeatmap.leadingBlankCount(month: month, calendar: calendar)

        let leadingNils = days.prefix(while: { $0 == nil }).count
        let filled = days.compactMap { $0 }.count
        let trailingNils = days.count - leadingNils - filled
        let expectedTrailing = (7 - (leading + 31) % 7) % 7

        #expect(leadingNils == leading)
        #expect(filled == 31)
        #expect(trailingNils == expectedTrailing)
    }

    private static func utcCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private static func firstOfMonth(_ year: Int, _ month: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }
}

/// `veryShortWeekdaySymbols` 는 항상 일요일부터 시작한다 — 회전을 빼먹으면
/// `firstWeekday != 1` 인 로케일에서 헤더가 그리드 열과 어긋난다.
@Suite("CalendarHeatmap 요일 헤더 회전")
struct CalendarHeatmapWeekdaySymbolTests {

    @Test("firstWeekday 1(일요일) 이면 원본 순서 그대로다")
    func sundayStartKeepsOriginalOrder() {
        let calendar = CalendarHeatmapWeekdaySymbolTests.koreanCalendar(firstWeekday: 1)

        #expect(
            CalendarHeatmap.rotatedWeekdaySymbols(calendar: calendar)
                == ["일", "월", "화", "수", "목", "금", "토"]
        )
    }

    @Test("firstWeekday 2(월요일) 면 일요일이 맨 뒤로 밀린다")
    func mondayStartRotatesSundayToEnd() {
        let calendar = CalendarHeatmapWeekdaySymbolTests.koreanCalendar(firstWeekday: 2)

        #expect(
            CalendarHeatmap.rotatedWeekdaySymbols(calendar: calendar)
                == ["월", "화", "수", "목", "금", "토", "일"]
        )
    }

    @Test("firstWeekday 7(토요일) 이면 토요일이 맨 앞으로 온다")
    func saturdayStartRotatesSaturdayToFront() {
        let calendar = CalendarHeatmapWeekdaySymbolTests.koreanCalendar(firstWeekday: 7)

        #expect(
            CalendarHeatmap.rotatedWeekdaySymbols(calendar: calendar)
                == ["토", "일", "월", "화", "수", "목", "금"]
        )
    }

    /// 로케일을 고정해 호스트 환경의 기본 로케일과 무관하게 같은 심볼 배열을 받는다.
    private static func koreanCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}

/// `HeatmapCell.date` 는 Domain 값에서 그대로 넘어오며 시:분:초가 섞여 있을 수 있다.
/// 키잉(`cellsByDay` 내부)과 조회(그리드 날짜) 양쪽 모두 `startOfDay` 로 정규화해야
/// 같은 날이 매칭된다 — 한쪽만 정규화하면 조용히 "기록 없음" 으로 빠진다.
@Suite("CalendarHeatmap 날짜 매칭")
struct CalendarHeatmapCellsByDayTests {

    /// 셀 날짜(15:30)와 조회 날짜(09:00)를 일부러 다른 시각으로 둔다 — 둘 다 같은 날
    /// 자정으로 정규화되어야만 매칭되므로, 키잉·조회 어느 한쪽의 정규화만 빠져도
    /// 이 테스트가 실패한다.
    @Test("셀 날짜와 조회 날짜가 서로 다른 시각이어도 같은 날이면 매칭된다")
    func cellAndLookupWithDifferentTimeComponentsMatchOnSameDay() {
        let calendar = CalendarHeatmapCellsByDayTests.utcCalendar()
        let cellDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 3, hour: 15, minute: 30)
        )!
        let lookupDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 3, hour: 9)
        )!
        let cell = HeatmapCell(date: cellDate, ratio: 0.012)

        let cellsByDay = CalendarHeatmap.cellsByDay([cell], calendar: calendar)

        #expect(cellsByDay[calendar.startOfDay(for: lookupDate)]?.ratio == 0.012)
    }

    @Test("다른 날의 셀은 매칭되지 않는다")
    func cellOnDifferentDayDoesNotMatch() {
        let calendar = CalendarHeatmapCellsByDayTests.utcCalendar()
        let cellDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let lookupDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4))!
        let cell = HeatmapCell(date: cellDate, ratio: 0.012)

        let cellsByDay = CalendarHeatmap.cellsByDay([cell], calendar: calendar)

        #expect(cellsByDay[calendar.startOfDay(for: lookupDate)] == nil)
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
