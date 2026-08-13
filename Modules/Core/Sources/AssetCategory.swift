//
//  AssetCategory.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation

/// 포트폴리오 분류 축. DesignSystem 이 색·아이콘 매핑에 쓰므로 Domain 이 아닌 Core 에 둔다.
public enum AssetCategory: String, Codable, Sendable, CaseIterable {
    case cash
    case domesticStock
    case overseasStock
    case etf
    case crypto
    /// 순자산에서 빼는 유일한 분류. 선언 순서가 곧 화면 순서라 항상 마지막에 둔다.
    case loan
}

/// 분류를 화면 문구로 옮기는 어휘. 색·아이콘이 DesignSystem 에 있는 것과 같은 이유로
/// 여기 둔다 — 네 탭이 같은 이름을 써야 하고, 그 이름은 도메인 계산과 무관하다.
public extension AssetCategory {
    var title: String {
        switch self {
        case .cash: "현금"
        case .domesticStock: "국내주식"
        case .overseasStock: "해외주식"
        case .etf: "ETF"
        case .crypto: "코인"
        case .loan: "대출"
        }
    }

    /// 수량 뒤에 붙는 단위. 잔액으로 끝나는 분류는 셀 것이 없어 단위가 없다.
    var quantityUnit: String? {
        switch self {
        case .cash, .loan: nil
        case .domesticStock, .overseasStock, .etf: "주"
        case .crypto: "개"
        }
    }

    /// 수량 입력 필드의 라벨.
    var quantityFieldTitle: String {
        isBalanceOnly ? "잔액" : "수량"
    }

    /// 이름 입력 필드의 라벨. 통장도 대출도 "종목" 이 아니다.
    var nameFieldTitle: String {
        isBalanceOnly ? "이름" : "종목명"
    }

    /// 순자산에서 빼는 분류인지. 오늘 금액의 부호가 아니라 분류의 성질로 판정한다 —
    /// 전액 상환해 잔액이 0 이어도 대출은 자산이 아니다.
    var isLiability: Bool { self == .loan }

    /// 잔액 한 칸으로 끝나는 분류인지 — 티커·평단가·시세가 없다.
    var isBalanceOnly: Bool { self == .cash || self == .loan }
}
