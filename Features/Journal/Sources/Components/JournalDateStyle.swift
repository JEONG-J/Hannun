//
//  JournalDateStyle.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 일지 날짜 문구. 최근 이틀은 상대 표기를 쓰고 그 앞은 절대 표기로 바꾼다.
struct JournalDateStyle {
    // MARK: - Property

    private let calendar: Calendar

    // MARK: - Function

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 목록 셀용 짧은 표기 — "오늘" / "어제" / "7월 25일 (금)".
    func listText(for date: Date) -> String {
        if calendar.isDateInToday(date) { return Constants.todayText }
        if calendar.isDateInYesterday(date) { return Constants.yesterdayText }

        let day = date.formatted(.dateTime.month().day())
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))
        return "\(day) (\(weekday))"
    }

    /// 작성·상세용 전체 표기 — "2026년 8월 1일 (토) 오후 2:32".
    func timestampText(for date: Date) -> String {
        let day = date.formatted(.dateTime.year().month().day())
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))
        let time = date.formatted(.dateTime.hour().minute())
        return "\(day) (\(weekday)) \(time)"
    }
}

fileprivate enum Constants {
    static let todayText = "오늘"
    static let yesterdayText = "어제"
}
