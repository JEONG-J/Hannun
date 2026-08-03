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
