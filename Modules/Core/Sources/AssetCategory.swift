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
        }
    }

    /// 수량 뒤에 붙는 단위. 현금은 수량이 아니라 잔액을 다루므로 단위가 없다.
    var quantityUnit: String? {
        switch self {
        case .cash: nil
        case .domesticStock, .overseasStock, .etf: "주"
        case .crypto: "개"
        }
    }

    /// 수량 입력 필드의 라벨. 현금만 "잔액" 으로 바뀐다.
    var quantityFieldTitle: String {
        self == .cash ? "잔액" : "수량"
    }
}
