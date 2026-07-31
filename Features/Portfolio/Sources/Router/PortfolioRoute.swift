//
//  PortfolioRoute.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDomain

/// 포트폴리오 탭 안에서 push 로 열리는 화면.
enum PortfolioRoute: Hashable {
    case cashFlowList
}

/// 종목 편집 sheet 가 열리는 경우 (PF-2 추가 / PF-3 수정).
enum HoldingEditorMode: Identifiable {
    case create
    case edit(HoldingRecord)

    var id: String {
        switch self {
        case .create: Constants.createIdentifier
        case .edit(let holding): holding.id.uuidString
        }
    }

    var editingHolding: HoldingRecord? {
        switch self {
        case .create: nil
        case .edit(let holding): holding
        }
    }
}

/// 입출금 기록 편집 sheet 가 열리는 경우 (PF-5 추가 / PF-6 수정).
enum CashFlowEditorMode: Identifiable {
    case create
    case edit(CashFlowRecord)

    var id: String {
        switch self {
        case .create: Constants.createIdentifier
        case .edit(let event): event.id.uuidString
        }
    }

    var editingEvent: CashFlowRecord? {
        switch self {
        case .create: nil
        case .edit(let event): event
        }
    }
}

fileprivate enum Constants {
    /// UUID 와 섞이지 않는 값이면 무엇이든 된다 — sheet 재사용을 막는 용도일 뿐이다.
    static let createIdentifier = "create"
}
