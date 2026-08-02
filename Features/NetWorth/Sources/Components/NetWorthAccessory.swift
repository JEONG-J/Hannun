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
///
/// 값이 아니라 ViewModel 을 통째로 받는다. 액세서리는 `TabAccessoryHost` 가 **첫 등장 시점에
/// 붙잡아 둔 클로저**로 그려지므로, 바깥에서 `freshness` 같은 값을 꺼내 넘기면 그 시점 값이
/// 그대로 굳어 시세를 받아와도 캡션이 영영 "불러오는 중"에 머문다. 참조를 넘겨 이 안에서 읽으면
/// Observation 이 추적해 정상적으로 다시 그려진다.
struct NetWorthAccessory: View {

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable private var viewModel: NetWorthViewModel

    private var freshness: QuoteFreshness { viewModel.freshness }

    // MARK: - Body

    init(viewModel: NetWorthViewModel) {
        _viewModel = Bindable(viewModel)
    }

    var body: some View {
        BottomAccessory {
            caption
        } trailing: {
            CurrencyToggle(selection: $viewModel.baseCurrency)
        }
    }

    @ViewBuilder
    private var caption: some View {
        switch freshness {
        case .unknown:
            AccessoryCaption(Constants.pendingCaption)

        case let .fresh(date):
            AccessoryCaption(
                value: date.formatted(date: .omitted, time: .shortened),
                suffix: captionSuffix
            )

        case let .stale(since):
            staleBadge(since: since)
        }
    }

    // MARK: - Function

    /// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 캡션을 숨기는 대신 줄인다.
    /// "시세"를 빼도 통화 토글이 바로 옆에 있어 무슨 기준인지는 이미 읽힌다.
    private var captionSuffix: String {
        layout == .inline || dynamicTypeSize.isAccessibilitySize
            ? Constants.inlineCaptionSuffix
            : Constants.expandedCaptionSuffix
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
    static let pendingCaption = "시세 불러오는 중"
    static let unavailableQuoteMessage = "갱신 실패 · 시세 없는 종목 포함"
    static let secondsPerMinute: TimeInterval = 60
    static let expandedCaptionSuffix = "시세 기준"
    static let inlineCaptionSuffix = "기준"
}
