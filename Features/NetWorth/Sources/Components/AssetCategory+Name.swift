//
//  AssetCategory+Name.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore

/// 공유 계층에 카테고리 표시 이름이 아직 없어 화면에서 정의한다.
/// 포트폴리오 탭도 같은 문구가 필요하므로 Core 로 올리는 편이 맞다.
extension AssetCategory {
    var name: String {
        switch self {
        case .cash: "현금"
        case .domesticStock: "국내주식"
        case .overseasStock: "해외주식"
        case .etf: "ETF"
        case .crypto: "코인"
        }
    }
}
