//
//  HoldingValuator.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 보유 종목 1건의 평가 결과. 금액은 모두 기준 통화로 환산된 값이다.
public struct HoldingValuation: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let holding: HoldingRecord

    /// 1주(1개)당 현재가. 잔액만 다루는 현금·대출은 nil.
    public let currentPrice: Money?

    /// 기준 통화 평가액. 부채는 음수다.
    public let marketValue: Money

    /// 매입원가. 평단가가 없는 현금·대출은 nil.
    public let costBasis: Money?

    /// 이 평가에 쓰인 가격이 언제 것인지 (NW-1 갱신 실패 배지의 근거).
    public let priceFreshness: PriceFreshness

    public var id: UUID { holding.id }

    public var profit: Money? {
        guard let costBasis else { return nil }
        return Money(amount: marketValue.amount - costBasis.amount, currency: marketValue.currency)
    }

    /// 0.12 == 12%.
    public var returnRate: Decimal? {
        guard let costBasis, costBasis.amount > 0 else { return nil }
        return (marketValue.amount - costBasis.amount) / costBasis.amount
    }

    // MARK: - Function

    public init(
        holding: HoldingRecord,
        currentPrice: Money?,
        marketValue: Money,
        costBasis: Money?,
        priceFreshness: PriceFreshness
    ) {
        self.holding = holding
        self.currentPrice = currentPrice
        self.marketValue = marketValue
        self.costBasis = costBasis
        self.priceFreshness = priceFreshness
    }
}

/// 보유 종목을 기준 통화 금액으로 옮기는 계산기.
///
/// 순자산·포트폴리오·성과 세 탭이 같은 숫자를 보여줘야 해서 계산을 한 군데로 모았다.
struct HoldingValuator {
    // MARK: - Property

    let baseCurrency: Currency
    let exchangeRate: ExchangeRate

    /// 티커 → 시세. 조회하지 못한 종목은 빠져 있다.
    let quotes: [String: Quote]

    // MARK: - Function

    func valuation(for holding: HoldingRecord) -> HoldingValuation {
        guard !holding.category.isBalanceOnly else {
            // 부채 잔액은 양수로 저장하고 평가 시점에만 뒤집는다 — 부호가 태어나는 유일한 자리다.
            // 위쪽 계층은 전부 `marketValue` 를 합산할 뿐이라 부호가 저절로 전파된다.
            let signed = holding.category.isLiability ? -holding.quantity : holding.quantity
            let balance = Money(amount: signed, currency: holding.currency)
            return HoldingValuation(
                holding: holding,
                currentPrice: nil,
                marketValue: exchangeRate.convert(balance, to: baseCurrency),
                costBasis: nil,
                priceFreshness: .notApplicable
            )
        }

        let unitPrice = unitPrice(for: holding)
        let marketValue = Money(
            amount: holding.quantity * unitPrice.amount,
            currency: unitPrice.currency
        )
        let costBasis = holding.averagePrice.map {
            Money(amount: holding.quantity * $0, currency: holding.currency)
        }

        return HoldingValuation(
            holding: holding,
            currentPrice: exchangeRate.convert(unitPrice, to: baseCurrency),
            marketValue: exchangeRate.convert(marketValue, to: baseCurrency),
            costBasis: costBasis.map { exchangeRate.convert($0, to: baseCurrency) },
            priceFreshness: quotes[holding.ticker]?.freshness ?? .unavailable
        )
    }

    /// 시세 → 수동 입력가 → 평단가 순으로 내려간다.
    ///
    /// 시세 조회가 실패해도 마지막으로 알고 있는 값을 쓰라는 정책의 계산 쪽 절반이다.
    /// 평단가마저 없으면 0 이 되고, 화면은 `priceFreshness` 를 보고 갱신 실패 배지를 띄운다.
    private func unitPrice(for holding: HoldingRecord) -> Money {
        if let fetched = quotes[holding.ticker] { return fetched.price }
        if let manual = holding.manualPrice {
            return Money(amount: manual, currency: holding.currency)
        }
        return Money(amount: holding.averagePrice ?? 0, currency: holding.currency)
    }
}
