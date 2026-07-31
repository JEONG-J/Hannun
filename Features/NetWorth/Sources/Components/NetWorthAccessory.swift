//
//  NetWorthAccessory.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDesignSystem
import SwiftUI

/// 순자산 탭 하단 액세서리 — 갱신 시각 캡션 + 기준 통화 세그먼트 (NW-1, NW-2).
///
/// 갱신에 실패하면 캡션이 그대로 `StaleBadge` 로 바뀐다. 콘텐츠 영역에 배지를 따로 띄우지
/// 않는 이유는 이 캡션이 이미 "지금 보고 있는 숫자가 언제 것인지"를 말하는 자리이기 때문이다.
struct NetWorthAccessory: View {

    // MARK: - Property

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private let freshness: QuoteFreshness
    @Binding private var baseCurrency: Currency

    // MARK: - Body

    init(freshness: QuoteFreshness, baseCurrency: Binding<Currency>) {
        self.freshness = freshness
        _baseCurrency = baseCurrency
    }

    var body: some View {
        BottomAccessory {
            caption

            Spacer(minLength: .spacingS)

            CurrencyToggle(selection: $baseCurrency)
        }
    }

    @ViewBuilder
    private var caption: some View {
        switch freshness {
        case .unknown:
            captionText(Constants.pendingCaption)

        case let .fresh(date):
            if isInline {
                captionText(Constants.inlineCaption(at: timeText(date)))
            } else {
                Label(
                    Constants.expandedCaption(at: timeText(date)),
                    systemImage: Constants.refreshSymbolName
                )
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .padding(.leading, .spacingS)
            }

        case let .stale(since):
            staleBadge(since: since)
                .padding(.leading, .spacingS)
        }
    }

    // MARK: - Function

    private func captionText(_ text: String) -> some View {
        Text(text)
            .hannunFont(.caption)
            .foregroundStyle(Color.textSecondary)
            .lineLimit(1)
            .padding(.leading, .spacingS)
    }

    private var isInline: Bool { placement == .inline }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// 시세를 한 번도 받지 못한 종목만 낡았다면 "몇 분 전"을 말할 근거가 없다.
    /// 이럴 때 0분으로 적으면 방금 받은 값처럼 읽히므로 문구를 따로 쓴다.
    @ViewBuilder
    private func staleBadge(since date: Date?) -> some View {
        if let date {
            StaleBadge(minutesElapsed: minutesElapsed(since: date))
        } else {
            StaleBadge(message: Constants.unavailableQuoteMessage)
        }
    }

    private func minutesElapsed(since date: Date) -> Int {
        max(0, Int(Date.now.timeIntervalSince(date) / Constants.secondsPerMinute))
    }
}

fileprivate enum Constants {
    static let refreshSymbolName = "arrow.clockwise"
    static let pendingCaption = "시세 불러오는 중"
    static let unavailableQuoteMessage = "갱신 실패 · 시세 없는 종목 포함"
    static let secondsPerMinute: TimeInterval = 60

    static func expandedCaption(at time: String) -> String { "\(time) 시세 기준" }
    static func inlineCaption(at time: String) -> String { "\(time) 기준" }
}
