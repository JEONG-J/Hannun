//
//  CashFlowRow.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 입출금 기록 1건. 금액은 부호를 그대로 드러내 입금/출금을 한눈에 가른다.
struct CashFlowRow: View {

    // MARK: - Property

    let event: CashFlowRecord

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: .spacingM) {
            identity

            Spacer(minLength: .spacingS)

            AmountText(event.signedMoney, size: .row, showsPositiveSign: true)
        }
        .padding(.vertical, .spacingM)
        .padding(.horizontal, .spacingL)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            HStack(spacing: .spacingXS) {
                Image(systemName: CashFlowKindText.systemImageName(for: event.kind))
                    .imageScale(.small)
                    .foregroundStyle(Color.textSecondary)

                Text(CashFlowKindText.title(for: event.kind))
                    .hannunFont(.rowTitle)
                    .foregroundStyle(Color.textPrimary)
            }

            Text(meta)
                .hannunFont(.caption, tabularFigures: true)
                .foregroundStyle(Color.textSecondary)
        }
        .lineLimit(1)
    }

    private var meta: String {
        let date = event.occurredOn.formatted(.dateTime.month().day())
        guard !event.memo.isEmpty else { return date }
        return date + Constants.separator + event.memo
    }
}

fileprivate enum Constants {
    static let separator = " · "
}

#if DEBUG
#Preview("입출금 행") {
    VStack(spacing: 0) {
        CashFlowRow(
            event: CashFlowRecord(
                occurredOn: .now,
                amount: 3_000_000,
                kind: .deposit,
                memo: "월급 이체"
            )
        )

        Divider()

        CashFlowRow(
            event: CashFlowRecord(occurredOn: .now, amount: 500_000, kind: .withdrawal)
        )
    }
    .background(Color.surfacePrimary, in: .hannunContainer())
    .padding(.spacingL)
    .background(Color.backgroundPrimary)
}
#endif
