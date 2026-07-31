//
//  ExchangeRate.swift
//  HannunCore
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// USD/KRW 환산율.
///
/// 순자산·포트폴리오·성과 세 탭이 같은 규칙으로 통화를 바꿔야 해서 `Money` 옆에 둔다.
public struct ExchangeRate: Equatable, Sendable {
    // MARK: - Property

    /// 1 USD 에 해당하는 원화 금액.
    public let krwPerUSD: Decimal

    // MARK: - Function

    public init(krwPerUSD: Decimal) {
        self.krwPerUSD = krwPerUSD
    }

    /// 환율이 유효하지 않으면 0 을 돌려준다.
    ///
    /// 환산 자체를 실패시키지 않는 이유는 시세·환율 조회 실패가 화면을 비우면 안 되기 때문이다.
    /// 값이 낡았다는 사실은 갱신 실패 배지가 따로 알린다.
    public func convert(_ money: Money, to currency: Currency) -> Money {
        guard money.currency != currency else { return money }
        guard krwPerUSD > 0 else { return Money(amount: 0, currency: currency) }

        return switch currency {
        case .krw: Money(amount: money.amount * krwPerUSD, currency: .krw)
        case .usd: Money(amount: money.amount / krwPerUSD, currency: .usd)
        }
    }
}
