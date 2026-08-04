//
//  PortfolioRoute.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDomain

/// 포트폴리오 탭이 지금 보여 주는 화면.
///
/// push 목적지가 아니라 **탭 루트에 갈아 끼우는 면**이다. 종목 목록과 입출금 기록은 상하
/// 관계가 아니라 같은 탭을 앞뒤로 뒤집은 두 면이고, 오가는 자리도 하단 액세서리 하나뿐이다.
/// 스택에 쌓으면 돌아오는 길이 뒤로가기와 캡슐 둘로 갈라지는 데다, 캡슐은 push 된 뒤에도
/// 그대로 떠 있어 같은 화면을 두 겹으로 쌓을 수 있다.
enum PortfolioRoute {
    case holdings
    case cashFlow

    /// 액세서리를 누르면 갈 곳. 면이 둘뿐이라 "다음"이 곧 "반대편"이다.
    var counterpart: PortfolioRoute {
        self == .holdings ? .cashFlow : .holdings
    }

    var title: String {
        switch self {
        case .holdings: Constants.holdingsTitle
        case .cashFlow: Constants.cashFlowTitle
        }
    }
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
    static let holdingsTitle = "포트폴리오"
    static let cashFlowTitle = "입출금 기록"
}
