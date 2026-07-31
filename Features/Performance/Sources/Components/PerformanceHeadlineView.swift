//
//  PerformanceHeadlineView.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import SwiftUI

/// 화면 최상단 큰 숫자 블록 (PM-3).
///
/// 스크럽 중에는 같은 자리에서 그 시점 값으로 바뀌므로 캡션도 함께 바뀐다 — 기준선이
/// 연초에서 기간 시작으로 옮겨간다는 사실을 숨기면 숫자를 오독하게 된다.
struct PerformanceHeadlineView: View {

    // MARK: - Property

    private let headline: PerformanceHeadline

    // MARK: - Body

    init(_ headline: PerformanceHeadline) {
        self.headline = headline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(caption)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            Text(AmountFormatter.percentage(ratio: headline.rate))
                .hannunFont(.displayAmount, tabularFigures: true)
                .foregroundStyle(ChangeDirection(headline.rate).color)
                .contentTransition(.numericText())
                .hannunAnimation(.standard, value: headline.rate)

            if let amount = headline.amount {
                amountLine(amount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Function

    private var caption: String {
        guard let scrubbedDate = headline.scrubbedDate else { return Constants.yearToDateCaption }

        let date = scrubbedDate.formatted(.dateTime.year().month().day())
        return "\(date) \(Constants.captionSeparator) \(Constants.periodStartCaption)"
    }

    private func amountLine(_ amount: Money) -> some View {
        HStack(spacing: .spacingXS) {
            Text(headline.isScrubbing ? Constants.totalLabel : Constants.yearOpeningLabel)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            AmountText(amount, size: .sub, showsPositiveSign: !headline.isScrubbing)
        }
    }
}

fileprivate enum Constants {
    static let yearToDateCaption = "YTD 수익률 (입출금 제외)"
    static let periodStartCaption = "기간 시작 대비"
    static let captionSeparator = "·"
    static let yearOpeningLabel = "연초 대비"
    static let totalLabel = "총자산"
}

#if DEBUG
#Preview("성과 헤드라인 · 라이트") {
    VStack(alignment: .leading, spacing: .spacingXL) {
        PerformanceHeadlineView(
            PerformanceHeadline(scrubbedDate: nil, rate: 0.094, amount: .krw(9_140_000))
        )

        PerformanceHeadlineView(
            PerformanceHeadline(scrubbedDate: nil, rate: -0.0312, amount: .krw(-3_120_000))
        )

        PerformanceHeadlineView(
            PerformanceHeadline(
                scrubbedDate: Date(timeIntervalSince1970: 1_769_904_000),
                rate: 0.0412,
                amount: .krw(128_450_000)
            )
        )
    }
    .padding(.spacingL)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.backgroundPrimary)
    .preferredColorScheme(.light)
}

#Preview("성과 헤드라인 · 다크") {
    PerformanceHeadlineView(
        PerformanceHeadline(scrubbedDate: nil, rate: 0.094, amount: .krw(9_140_000))
    )
    .padding(.spacingL)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.backgroundPrimary)
    .preferredColorScheme(.dark)
}
#endif
