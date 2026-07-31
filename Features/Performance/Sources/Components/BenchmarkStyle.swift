//
//  BenchmarkStyle.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import HannunDomain
import SwiftUI

extension BenchmarkIndex {

    var title: String {
        switch self {
        case .kospi: "코스피"
        case .sp500: "S&P500"
        case .nasdaq: "나스닥"
        case .bitcoin: "BTC"
        }
    }

    /// 오버레이 라인 색이자 선택된 칩 색. 칩이 곧 범례라 둘이 갈리면 안 된다 (UI 스펙 §4.3).
    ///
    /// 지수의 성격에 맞는 카테고리 토큰을 빌려 쓴다 — 벤치마크 전용 색을 새로 만들면
    /// 도넛·소계와 색 어휘가 둘로 갈린다.
    var lineColor: Color {
        switch self {
        case .kospi: .categoryDomestic
        case .sp500: .categoryForeign
        case .nasdaq: .categoryEtf
        case .bitcoin: .categoryCrypto
        }
    }
}
