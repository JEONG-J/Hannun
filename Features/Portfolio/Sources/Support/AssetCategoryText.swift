//
//  AssetCategoryText.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore

/// 카테고리를 화면 문구로 옮기는 매핑.
///
/// DesignSystem 의 `AssetCategoryStyle` 은 색과 심볼만 갖고 있어 이름이 없다. 다른 탭도 같은
/// 이름을 쓰게 되면 공용 모듈로 올려야 하지만, 지금은 이 탭 안에 둔다.
enum AssetCategoryText {

    // MARK: - Function

    static func title(for category: AssetCategory) -> String {
        switch category {
        case .cash: "현금"
        case .domesticStock: "국내주식"
        case .overseasStock: "해외주식"
        case .etf: "ETF"
        case .crypto: "코인"
        }
    }

    /// 수량 뒤에 붙는 단위. 현금은 수량 대신 잔액을 다루므로 단위가 없다.
    static func quantityUnit(for category: AssetCategory) -> String? {
        switch category {
        case .cash: nil
        case .domesticStock, .overseasStock, .etf: "주"
        case .crypto: "개"
        }
    }

    /// 수량 입력 필드의 라벨. 현금만 "잔액" 으로 바뀐다.
    static func quantityFieldTitle(for category: AssetCategory) -> String {
        category == .cash ? "잔액" : "수량"
    }
}
