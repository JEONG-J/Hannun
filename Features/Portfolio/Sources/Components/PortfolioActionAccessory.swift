//
//  PortfolioActionAccessory.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDesignSystem
import SwiftUI

/// 포트폴리오 탭의 하단 액세서리 — 목록 상태 한 줄 + 화면 전환 하나 (PF-5/6).
///
/// **캡슐 전체가 전환 버튼이다.** 이 탭의 액세서리에 남은 동작은 종목 목록 ↔ 입출금 기록
/// 하나뿐이라, 오른쪽 라벨만 눌리게 두면 44pt 남짓한 과녁 하나를 위해 나머지 캡슐이 죽는다.
/// 그래서 오른쪽은 알약도 테두리도 없는 글자로 내리고, 누르는 자리는 캡슐 전부다. 종목
/// 추가는 신규 사용자가 처음 만나는 진입점이라 축약에 기대지 않는 상시 노출이 필요해 목록
/// 화면의 우상단 툴바로 올라갔다 — 양쪽에 같은 액션을 두는 중복 배치는 하지 않는다.
///
/// 오른쪽에는 지금 있는 화면이 아니라 **갈 곳**을 적는다. 순자산 탭의 통화 라벨과 반대인데,
/// 거기서 오른쪽은 "이 숫자가 무슨 통화인지" 를 말하는 값이라 현재를 적어야 맞고 (KRW 화면에
/// USD 라고 쓰여 있을 수는 없다), 여기서 오른쪽은 목적지 이름이라 갈 곳을 적어야 맞다.
/// 입출금 기록으로 넘어가면 라벨이 "포트폴리오" 로 뒤집혀, 돌아올 길이 여기라고 말한다.
///
/// 왼쪽은 두 화면에서 같은 말을 한다 — 이 탭의 주어는 언제나 보유 종목이라서다. 목록에
/// 있을 때는 지금 보고 있는 것을 세고, 입출금 기록에 있을 때는 옆 라벨과 붙어 "12종목으로
/// 돌아간다" 로 읽힌다. 화면마다 문구를 갈아 끼우면 캡슐 폭이 널뛰는 대가만 치른다.
/// 히어로(요약 바)가 이미 금액을 말하고 있으니 여기서는 **몇 종목을 언제 기준으로** 만 맡는다.
///
/// 값이 아니라 ViewModel·Router 를 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다. 참조로 들고 이 안에서 읽어야 Observation 이 추적한다.
struct PortfolioActionAccessory: View {

    // MARK: - Property

    @Environment(\.colorScheme) private var colorScheme

    private let viewModel: PortfolioListViewModel
    private let router: PortfolioRouter

    // MARK: - Body

    init(viewModel: PortfolioListViewModel, router: PortfolioRouter) {
        self.viewModel = viewModel
        self.router = router
    }

    var body: some View {
        Button {
            router.toggleRoute()
        } label: {
            BottomAccessory {
                caption
            } trailing: {
                destinationLabel
            }
            // 캡슐 높이를 다 쓰고 그 사각형 전체를 과녁으로 선언한다. 이게 없으면 히트
            // 영역이 **글자가 그려진 픽셀**로 좁아져, 캡션과 라벨 사이 빈 공간이 안 눌린다.
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            String(format: Constants.switchHintFormat, router.route.counterpart.title)
        )
        .hannunAnimation(.selection, value: router.route)
    }

    /// 종목이 없을 때는 셀 것이 없다는 사실만 말한다. 옆 라벨이 입출금 기록이라
    /// "첫 종목을 추가해 보세요" 류의 유도 문구를 두면 그 라벨을 가리키는 말로 읽힌다.
    /// 종목 추가 유도는 빈 상태 화면과 툴바가 맡는다.
    @ViewBuilder
    private var caption: some View {
        if !viewModel.hasHoldings {
            AccessoryCaption(Constants.emptyCaption)
        } else if let loadedAt = viewModel.lastLoadedAt {
            AccessoryCaption(
                .value(holdingCountText),
                .plain(Constants.captionSeparator
                    + loadedAt.formatted(date: .omitted, time: .shortened)
                    + Constants.captionSuffix)
            )
        } else {
            AccessoryCaption(.value(holdingCountText))
        }
    }

    // MARK: - Function

    /// 갈 화면의 이름. 면이 둘뿐이라 좌우 화살표 하나로 "여기와 저기를 오간다" 가 다 읽힌다 —
    /// 어느 쪽으로 가는지까지 심볼로 말하려 들면 화면마다 방향을 뒤집어야 하고, 그건 두 면
    /// 사이에 없는 앞뒤를 지어내는 셈이다.
    ///
    /// 다크에서 `brand` 는 4.07:1 로 AA 미달이라 잉크로 내린다. 그 대신 다크에서는 눌린다는
    /// 신호가 위치(캡슐 오른쪽 끝)와 화살표에만 남는다.
    ///
    /// 높이를 44pt 로 잡는 건 이 글자의 과녁이 아니라 **캡슐 내용의 최소 높이** 를 위해서다.
    /// 누르는 자리는 캡슐 전부이고, 내용이 얇아지면 그 과녁도 같이 얇아진다.
    private var destinationLabel: some View {
        Label(router.route.counterpart.title, systemImage: Constants.switchSymbolName)
            .hannunFont(.pillLabel)
            .foregroundStyle(colorScheme == .dark ? Color.textPrimary : Color.brand)
            .lineLimit(1)
            // 기본값인 `.interpolate` 는 글리프를 보간해 두 이름이 겹쳐 뭉개진다. 서로 무관한
            // 글자를 섞어 봐야 얻을 게 없으므로 크로스페이드로 갈아끼운다.
            .contentTransition(.opacity)
            .frame(minHeight: .minimumTouchTarget)
    }

    private var holdingCountText: String {
        "\(viewModel.visibleHoldingCount)\(Constants.holdingCountUnit)"
    }
}

fileprivate enum Constants {
    static let switchSymbolName = "arrow.left.arrow.right"
    static let switchHintFormat = "두 번 탭하면 %@로 바꿉니다"
    static let emptyCaption = "아직 종목이 없어요"
    static let holdingCountUnit = "종목"
    static let captionSeparator = "· "
    static let captionSuffix = " 기준"
}
