//
//  Quote.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 한 종목의 현재가와 그 값을 언제 받아왔는지.
///
/// 가격만 돌려주면 "갱신에 실패해 마지막 캐시값을 쓰는 중"인지 화면이 알 수 없다.
/// 조회 성패는 종목마다 갈리므로 신선도도 종목 단위로 따라다닌다 (NW-1).
public struct Quote: Equatable, Sendable {
    // MARK: - Property

    public let price: Money

    /// 이 가격을 시장에서 받아온 시각.
    public let asOf: Date

    /// 유효 기간이 지난 값을 갱신하지 못해 그대로 쓰고 있는지.
    public let isStale: Bool

    // MARK: - Function

    public init(price: Money, asOf: Date, isStale: Bool = false) {
        self.price = price
        self.asOf = asOf
        self.isStale = isStale
    }
}

/// 평가에 쓰인 가격의 출처와 신선도.
public enum PriceFreshness: Equatable, Sendable {
    /// 유효 기간 안의 시세로 평가했다.
    case fresh(asOf: Date)

    /// 갱신에 실패해 이 시각의 시세를 그대로 쓰고 있다.
    case stale(since: Date)

    /// 시세를 한 번도 받지 못해 수동 입력가·평단가로 채웠다. 언제 것인지 말할 근거가 없다.
    case unavailable

    /// 시세라는 개념이 없다 (현금).
    case notApplicable

    /// 화면에 "갱신 실패"를 알려야 하는 상태인지.
    public var isStale: Bool {
        switch self {
        case .fresh, .notApplicable: false
        case .stale, .unavailable: true
        }
    }

    /// 갱신이 멈춘 시점. 시각을 알 수 없는 상태면 nil.
    public var staleSince: Date? {
        guard case let .stale(since) = self else { return nil }
        return since
    }
}

extension Quote {
    /// 시세를 평가 결과에 실을 신선도로 옮긴다.
    public var freshness: PriceFreshness {
        isStale ? .stale(since: asOf) : .fresh(asOf: asOf)
    }
}
