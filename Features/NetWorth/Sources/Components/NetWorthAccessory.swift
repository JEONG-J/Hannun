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

/// 순자산 탭 하단 액세서리 — 상태 한 줄 + 통화 전환 하나 (NW-1, NW-2).
///
/// 왼쪽은 스크롤 위치에 따라 말을 바꾼다. 히어로(총자산 블록)가 보이는 동안에는 그 숫자가
/// **언제 기준인지**를 말하고, 히어로가 밀려 나가면 **얼마인지**를 대신 말한다. 같은 숫자를
/// 한 화면에 두 번 적지 않으면서도 스크롤 아래에서 총자산을 잃지 않는다 (디자인 문서 §6).
///
/// 갱신에 실패하면 스크롤 위치와 무관하게 `StaleBadge` 가 자리를 차지한다 — 지금 보고 있는
/// 숫자를 믿어도 되는지가 그 숫자가 얼마인지보다 먼저다.
///
/// 오른쪽은 세그먼트가 아니라 **전환 버튼**이다. 라벨에 적힌 건 현재 통화가 아니라 **바뀔**
/// 통화이므로 누르면 무엇이 되는지가 그대로 보인다. 세그먼트를 쓰면 두 칸 중 한 칸은 늘
/// 아무 일도 하지 않는 버튼이 된다.
///
/// 값이 아니라 ViewModel 을 통째로 받는다. 액세서리는 `TabAccessoryHost` 가 **첫 등장 시점에
/// 붙잡아 둔 클로저**로 그려지므로, 바깥에서 `freshness` 같은 값을 꺼내 넘기면 그 시점 값이
/// 그대로 굳어 시세를 받아와도 캡션이 영영 "불러오는 중"에 머문다. 참조를 넘겨 이 안에서 읽으면
/// Observation 이 추적해 정상적으로 다시 그려진다.
struct NetWorthAccessory: View {

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let viewModel: NetWorthViewModel

    private var freshness: QuoteFreshness { viewModel.freshness }

    // MARK: - Body

    init(viewModel: NetWorthViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BottomAccessory {
            leading
        } trailing: {
            currencySwitch
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch freshness {
        case .unknown:
            AccessoryCaption(Constants.pendingCaption)

        case let .fresh(date):
            alternatingCaption(refreshedAt: date)

        case let .stale(since):
            staleBadge(since: since)
        }
    }

    // MARK: - Function

    /// 두 문구를 겹쳐 두고 투명도만 바꾼다. 이러면 프레임이 **넓은 쪽에 고정**되어 교대할 때마다
    /// 왼쪽 폭이 널뛰지 않고, 크로스페이드도 한 번에 얻는다.
    private func alternatingCaption(refreshedAt date: Date) -> some View {
        ZStack(alignment: .leading) {
            AccessoryCaption(
                value: date.formatted(date: .omitted, time: .shortened),
                suffix: captionSuffix
            )
            .opacity(viewModel.isHeroVisible ? 1 : 0)
            .accessibilityHidden(!viewModel.isHeroVisible)

            totalCaption
                .opacity(viewModel.isHeroVisible ? 0 : 1)
                .accessibilityHidden(viewModel.isHeroVisible)
        }
        .hannunAnimation(.selection, value: viewModel.isHeroVisible)
    }

    /// 액세서리 폭에는 전체 자릿수가 들어가지 않으므로 억·만 단위로 접는다. 정확한 값은
    /// 히어로가 들고 있고, 여기 있는 건 스크롤 아래에서도 규모를 잃지 않게 하는 요약이다.
    @ViewBuilder
    private var totalCaption: some View {
        if let total = viewModel.summary.value?.total {
            AccessoryCaption(.value(AmountFormatter.compact(total)))
        }
    }

    private var currencySwitch: some View {
        let target: Currency = viewModel.baseCurrency == .krw ? .usd : .krw

        return AccessoryControlButton(
            target.rawValue,
            isOn: false,
            indicatesSelection: false,
            accessibilityLabel: String(format: Constants.currencySwitchLabelFormat,
                                       target.displayName)
        ) {
            viewModel.baseCurrency = target
        }
    }

    /// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 캡션을 숨기는 대신 줄인다.
    /// "시세"를 빼도 통화 버튼이 바로 옆에 있어 무슨 기준인지는 이미 읽힌다.
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
    static let currencySwitchLabelFormat = "%@로 전환"
}
