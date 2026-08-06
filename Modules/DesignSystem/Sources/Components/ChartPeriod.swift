//
//  ChartPeriod.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/6/26.
//

import Foundation

/// 추이 차트가 그리는 구간. 차트 축과 직결된 컨트롤의 어휘라 디자인 시스템이 갖는다.
///
/// 고르는 손잡이는 `PeriodMenu` 다 — 차트 카드 헤더에 축약된 메뉴 캡슐 하나로 선다.
/// `id` 는 저장·비교용 식별자이므로 라벨(`title`)이 바뀌어도 건드리지 않는다.
///
/// `String` raw value 와 `CaseIterable` 을 걷은 이유는 `custom` 이다 — 두 시각을 달고 다니는
/// case 는 문자열 하나로 표현되지 않고 셀 수도 없다. 프리셋을 훑을 자리는 `presets` 가 맡는다.
public enum ChartPeriod: Hashable, Identifiable, Sendable {
    case oneMonth
    case threeMonths
    case sixMonths
    case yearToDate
    case oneYear
    case all
    /// 사용자가 직접 고른 구간. 시작월 1일 00:00 ~ 종료월 말일 23:59:59 다.
    case custom(start: Date, end: Date)

    /// 메뉴에 프리셋으로 세우는 순서. `CaseIterable` 을 대신한다 — 커스텀은 셀 수 없다.
    public static let presets: [ChartPeriod] = [
        .oneMonth, .threeMonths, .sixMonths, .yearToDate, .oneYear, .all,
    ]

    public var id: String {
        switch self {
        case .oneMonth: "oneMonth"
        case .threeMonths: "threeMonths"
        case .sixMonths: "sixMonths"
        case .yearToDate: "yearToDate"
        case .oneYear: "oneYear"
        case .all: "all"
        case let .custom(start, end): Constants.customIdentifier(start: start, end: end)
        }
    }

    public var title: String {
        switch self {
        case .oneMonth: "1개월"
        case .threeMonths: "3개월"
        case .sixMonths: "6개월"
        case .yearToDate: "올해"
        case .oneYear: "1년"
        case .all: "전체"
        case let .custom(start, end): Constants.customTitle(start: start, end: end)
        }
    }
}

fileprivate enum Constants {
    static let separator = " – "

    static func customIdentifier(start: Date, end: Date) -> String {
        "custom-\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)"
    }

    /// `2026.1 – 2026.8`. 라벨이 알약 하나에 들어가야 하므로 년·월만 남긴다 —
    /// "2026년 1월 – 2026년 8월" 은 차트 헤더 한 줄에서 옆의 단위 세그먼트를 밀어낸다.
    static func customTitle(start: Date, end: Date) -> String {
        "\(yearMonth(of: start))\(separator)\(yearMonth(of: end))"
    }

    private static func yearMonth(of date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        return "\(year).\(month)"
    }
}
