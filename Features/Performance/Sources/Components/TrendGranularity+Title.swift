//
//  TrendGranularity+Title.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunDomain

/// `GranularityToggle` 이 인라인 컨트롤을 쓰던 시절의 어휘. 그 컴포넌트는 기간·단위를
/// 액세서리로 올리며 사라졌지만, 이 이름표는 `PerformanceAccessory`·`periodSummary` 가
/// 여전히 읽는다.
extension TrendGranularity {
    var title: String {
        switch self {
        case .daily: "일별"
        case .monthly: "월별"
        }
    }
}
