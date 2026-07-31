//
//  CashFlowKindText.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDomain

/// 입출금 유형을 화면 문구로 옮기는 매핑.
enum CashFlowKindText {

    // MARK: - Function

    static func title(for kind: CashFlowKind) -> String {
        switch kind {
        case .deposit: "입금"
        case .withdrawal: "출금"
        }
    }

    static func systemImageName(for kind: CashFlowKind) -> String {
        switch kind {
        case .deposit: "arrow.down.circle"
        case .withdrawal: "arrow.up.circle"
        }
    }
}
