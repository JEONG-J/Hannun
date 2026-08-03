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
/// 갱신 실패는 이 자리에서 알리지 않는다. 액세서리 왼쪽은 한 줄뿐이라 경고 배지가 들어오면
/// 시각·총자산 교대가 통째로 멈춘다. 대신 **마지막으로 값을 채운 시각**을 그대로 적는다 —
/// 갱신에 실패하면 그 시각이 멈춰 있으므로, 낡았다는 사실은 시계가 알아서 말한다.
///
/// **캡슐 전체가 통화 전환 버튼이다.** 이 탭의 액세서리에는 동작이 하나뿐이라 오른쪽 글자만
/// 눌리게 두면 44pt 남짓한 과녁 하나를 위해 나머지 캡슐이 죽는다. 그래서 오른쪽은 컨트롤이
/// 아니라 **지금 어떤 통화로 보고 있는지 적은 상태 라벨**이고, 누르는 자리는 캡슐 전부다.
/// 라벨을 바뀔 통화로 적으면 KRW 화면에 USD 라고 쓰여 있게 되므로 현재 통화를 적는다 —
/// 누르면 무엇이 되는지는 VoiceOver 힌트가 말한다.
///
/// 값이 아니라 ViewModel 을 통째로 받는다. 액세서리는 `TabAccessoryHost` 가 **첫 등장 시점에
/// 붙잡아 둔 클로저**로 그려지므로, 바깥에서 `lastRefreshedAt` 같은 값을 꺼내 넘기면 그 시점
/// 값이 그대로 굳어 시세를 받아와도 캡션이 영영 "불러오는 중"에 머문다. 참조를 넘겨 이 안에서
/// 읽으면 Observation 이 추적해 정상적으로 다시 그려진다.
struct NetWorthAccessory: View {

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let viewModel: NetWorthViewModel

    /// 누르면 넘어갈 통화. 라벨이 아니라 **동작**의 대상이라 화면에는 적지 않는다.
    private var targetCurrency: Currency {
        viewModel.baseCurrency == .krw ? .usd : .krw
    }

    // MARK: - Body

    init(viewModel: NetWorthViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            viewModel.baseCurrency = targetCurrency
        } label: {
            BottomAccessory {
                leading
            } trailing: {
                currencyLabel
            }
            // 캡슐 높이를 다 쓰고 그 사각형 전체를 과녁으로 선언한다. 이게 없으면 히트
            // 영역이 **글자가 그려진 픽셀**로 좁아져, 시각과 통화 사이 빈 공간이 안 눌린다.
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(viewModel.baseCurrency.displayName)
        .accessibilityHint(
            String(format: Constants.currencySwitchHintFormat, targetCurrency.displayName)
        )
        .hannunAnimation(.selection, value: viewModel.baseCurrency)
    }

    /// 한 번도 채우지 못했을 때만 시각이 없다. 그 외에는 언제 채운 값인지를 늘 말한다.
    @ViewBuilder
    private var leading: some View {
        if let lastRefreshedAt = viewModel.lastRefreshedAt {
            alternatingCaption(refreshedAt: lastRefreshedAt)
        } else {
            AccessoryCaption(Constants.pendingCaption)
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

    /// 지금 보고 있는 통화. 면도 스트로크도 두지 않고 왼쪽 캡션과 같은 한 줄 글자로 두되,
    /// 눌리는 캡슐이라는 신호는 색으로 남긴다. 다크에서 `brand` 는 4.07:1 로 AA 미달이라
    /// 잉크로 내린다 — 그 대신 다크에서는 어포던스가 위치(캡슐 오른쪽 끝)에만 남는다.
    ///
    /// 높이를 44pt 로 잡아 두는 건 이 글자의 과녁이 아니라 **캡슐 내용의 최소 높이**를 위해서다.
    /// 누르는 자리는 캡슐 전부이고, 내용이 얇아지면 그 과녁도 같이 얇아진다.
    ///
    /// VoiceOver 에는 숨긴다. 캡슐이 하나의 버튼이고 그 값이 이미 "원화 / 미국 달러"라
    /// 여기서 또 읽으면 "KRW, 원화"가 된다.
    private var currencyLabel: some View {
        Text(viewModel.baseCurrency.rawValue)
            .hannunFont(.pillLabel)
            .foregroundStyle(colorScheme == .dark ? Color.textPrimary : Color.brand)
            .lineLimit(1)
            // 기본값인 `.interpolate` 는 글리프를 보간해 KRW·USD 가 겹쳐 뭉개진다.
            // 서로 무관한 글자를 섞어 봐야 얻을 게 없으므로 크로스페이드로 갈아끼운다.
            .contentTransition(.opacity)
            .frame(minHeight: .minimumTouchTarget)
            .accessibilityHidden(true)
    }

    /// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 캡션을 숨기는 대신 줄인다.
    /// "시세"를 빼도 통화 버튼이 바로 옆에 있어 무슨 기준인지는 이미 읽힌다.
    private var captionSuffix: String {
        layout == .inline || dynamicTypeSize.isAccessibilitySize
            ? Constants.inlineCaptionSuffix
            : Constants.expandedCaptionSuffix
    }
}

fileprivate enum Constants {
    static let pendingCaption = "시세 불러오는 중"
    static let expandedCaptionSuffix = "시세 기준"
    static let inlineCaptionSuffix = "기준"
    static let currencySwitchHintFormat = "두 번 탭하면 %@로 바꿉니다"
}
