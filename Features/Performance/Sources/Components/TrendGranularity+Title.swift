//
//  TrendGranularity+Title.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunDomain

/// 차트 카드 헤더의 일별/월별 세그먼트가 칸마다 적는 이름표. 단위 어휘는 Domain 이 갖고
/// 그걸 한국어로 부르는 방식만 이 피처가 정한다.
extension TrendGranularity {
    var title: String {
        switch self {
        case .daily: "일별"
        case .monthly: "월별"
        }
    }
}
