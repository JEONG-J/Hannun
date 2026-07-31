//
//  HoldingValuationRow.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 평가 결과 1건을 `HoldingRow` 에 맞춰 문자열로 옮긴다.
///
/// 현금은 `subline` 과 `change` 를 비운다 — 평단가·수익률이 없는 자산이라 자리를 비워야
/// "값이 0" 이 아니라 "해당 없음" 으로 읽힌다 (PF-1).
struct HoldingValuationRow: View {

    // MARK: - Property

    let valuation: HoldingValuation
    let metric: HoldingMetric
    let onMetricTap: () -> Void

    private var holding: HoldingRecord { valuation.holding }

    // MARK: - Body

    var body: some View {
        HoldingRow(
            name: holding.name,
            ticker: holding.ticker.isEmpty ? nil : holding.ticker,
            subline: subline,
            amount: valuation.marketValue,
            change: change,
            onChangeTap: change == nil ? nil : onMetricTap
        )
    }

    private var subline: String? {
        guard holding.category != .cash else { return nil }

        let quantity = AmountFormatting.quantity(
            holding.quantity,
            unit: AssetCategoryText.quantityUnit(for: holding.category)
        )

        guard let priceText else { return quantity }
        return quantity + Constants.separator + priceText
    }

    /// 지표 순환에 따라 평단가와 현재가를 갈아 끼운다.
    private var priceText: String? {
        switch metric {
        case .currentPrice:
            guard let price = valuation.currentPrice else { return nil }
            return Constants.currentPriceLabel + AmountFormatting.text(for: price)
        case .returnRate, .profit:
            guard let price = averageUnitPrice else { return nil }
            return Constants.averagePriceLabel + AmountFormatting.text(for: price)
        }
    }

    /// 기준 통화로 환산한 평단가. 원가를 수량으로 되나눠 현재가와 통화를 맞춘다.
    private var averageUnitPrice: Money? {
        guard let costBasis = valuation.costBasis, holding.quantity > 0 else { return nil }
        return Money(amount: costBasis.amount / holding.quantity, currency: costBasis.currency)
    }

    private var change: ChangePillContent? {
        guard let returnRate = valuation.returnRate else { return nil }

        switch metric {
        case .profit:
            guard let profit = valuation.profit else { return .ratio(returnRate) }
            return .amount(profit)
        case .returnRate, .currentPrice:
            return .ratio(returnRate)
        }
    }
}

fileprivate enum Constants {
    static let separator = " · "
    static let averagePriceLabel = "평단 "
    static let currentPriceLabel = "현재 "
}

#if DEBUG
private struct HoldingValuationRowPreview: View {

    // MARK: - Property

    @State private var metric: HoldingMetric = .returnRate

    private let stock = HoldingValuation(
        holding: HoldingRecord(
            category: .domesticStock,
            name: "삼성전자",
            ticker: "005930",
            quantity: 100,
            averagePrice: 61_300
        ),
        currentPrice: .krw(69_100),
        marketValue: .krw(6_910_000),
        costBasis: .krw(6_130_000),
        priceFreshness: .fresh(asOf: .now)
    )

    private let cash = HoldingValuation(
        holding: HoldingRecord(category: .cash, name: "원화 예수금", quantity: 12_845_000),
        currentPrice: nil,
        marketValue: .krw(12_845_000),
        costBasis: nil,
        priceFreshness: .notApplicable
    )

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HoldingValuationRow(valuation: stock, metric: metric) { metric = metric.next }

            Divider()

            HoldingValuationRow(valuation: cash, metric: metric) {}
        }
        .background(Color.surfacePrimary, in: .hannunContainer())
        .padding(.spacingL)
        .background(Color.backgroundPrimary)
    }
}

#Preview("종목 행 · 지표 순환") {
    HoldingValuationRowPreview()
}
#endif
