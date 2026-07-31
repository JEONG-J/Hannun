//
//  HoldingRow.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 종목 행 2단 구조. 행당 주지표는 평가금액과 수익률 둘로 제한한다.
///
/// 현재가·수익금 같은 나머지 지표는 우측 pill 을 탭해 순환시키는 쪽으로 위임했다.
/// 다중 컬럼 테이블을 만들면 모바일 폭에서 어느 열도 읽히지 않는다.
///
/// 현금 행은 `subline` 과 `change` 를 비운다 — 평단가·수익률이 없는 자산이라 자리를 비워야
/// "값이 0" 이 아니라 "해당 없음" 으로 읽힌다.
public struct HoldingRow: View {

    // MARK: - Property

    private let name: String
    private let ticker: String?
    private let subline: String?
    private let amount: Money
    private let change: ChangePillContent?
    private let onChangeTap: (() -> Void)?

    // MARK: - Body

    public init(
        name: String,
        ticker: String? = nil,
        subline: String? = nil,
        amount: Money,
        change: ChangePillContent? = nil,
        onChangeTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.ticker = ticker
        self.subline = subline
        self.amount = amount
        self.change = change
        self.onChangeTap = onChangeTap
    }

    public var body: some View {
        HStack(alignment: .top, spacing: .spacingM) {
            identity

            Spacer(minLength: .spacingS)

            valuation
        }
        .padding(.vertical, .spacingM)
        .padding(.horizontal, .spacingL)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            HStack(spacing: .spacingXS) {
                Text(name)
                    .hannunFont(.rowTitle)
                    .foregroundStyle(Color.textPrimary)

                if let ticker {
                    Text(ticker)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if let subline {
                Text(subline)
                    .hannunFont(.caption, tabularFigures: true)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .lineLimit(1)
    }

    private var valuation: some View {
        VStack(alignment: .trailing, spacing: .spacingXS) {
            AmountText(amount, size: .row)

            if let change {
                changePill(change)
            }
        }
    }

    // MARK: - Function

    @ViewBuilder
    private func changePill(_ content: ChangePillContent) -> some View {
        if let onChangeTap {
            Button(action: onChangeTap) { ChangePill(content) }
                .buttonStyle(.plain)
        } else {
            ChangePill(content)
        }
    }
}

#if DEBUG
private struct HoldingRowPreview: View {

    // MARK: - Property

    @State private var showsProfitAmount = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HoldingRow(
                name: "삼성전자",
                ticker: "005930",
                subline: "10주 · ₩61,300",
                amount: .krw(6_910_000),
                change: showsProfitAmount
                    ? .amount(.krw(297_000))
                    : .ratio(0.0484),
                onChangeTap: { showsProfitAmount.toggle() }
            )

            Divider()
                .padding(.horizontal, .spacingL)

            HoldingRow(
                name: "Apple",
                ticker: "AAPL",
                subline: "24주 · $189.20",
                amount: .usd(4_968.72),
                change: .ratio(-0.0432)
            )

            Divider()
                .padding(.horizontal, .spacingL)

            HoldingRow(name: "원화 예수금", amount: .krw(12_845_000))
        }
        .background(Color.surfacePrimary, in: .hannunContainer())
        .padding(.spacingL)
        .background(Color.backgroundPrimary)
    }
}

#Preview("종목 행 · 라이트") {
    HoldingRowPreview()
        .preferredColorScheme(.light)
}

#Preview("종목 행 · 다크") {
    HoldingRowPreview()
        .preferredColorScheme(.dark)
}
#endif
