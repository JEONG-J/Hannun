//
//  PortfolioActionAccessory.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDesignSystem
import SwiftUI

/// 포트폴리오 탭의 하단 액세서리 — 목록 상태 한 줄 + 입출금 기록 하나 (PF-5/6).
///
/// 캡슐 오른쪽은 여전히 컨트롤 하나의 자리다. 액션 둘을 나란히 놓으면 축약 상태에서
/// 라벨이 들어가지 않아 Menu 로 접어야 하고, 접는 순간 "누르면 바로 되는 것"이던 액션이
/// "눌러서 고르는 것"으로 성격이 바뀐다. 그 한 자리를 이제 입출금 기록이 쓴다 — 종목
/// 추가는 신규 사용자가 처음 만나는 진입점이라 축약에 기대지 않는 상시 노출이 필요해
/// 목록 화면의 우상단 툴바로 올라갔다. 양쪽에 같은 액션을 두는 중복 배치는 하지 않는다.
///
/// 왼쪽은 스크롤과 무관하게 늘 같은 말을 한다. 이 탭의 히어로(요약 바)는 리스트 밖에
/// 고정돼 있어 스크롤로 사라지지 않으므로, 교대할 상대가 없다 (디자인 문서 §6).
/// 대신 히어로가 이미 금액을 말하고 있으니 액세서리는 **몇 종목을 언제 기준으로** 보고
/// 있는지를 맡는다.
///
/// 값이 아니라 ViewModel 을 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다.
struct PortfolioActionAccessory: View {

    // MARK: - Property

    private let viewModel: PortfolioListViewModel
    private let onShowCashFlow: () -> Void

    // MARK: - Body

    init(viewModel: PortfolioListViewModel, onShowCashFlow: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onShowCashFlow = onShowCashFlow
    }

    var body: some View {
        BottomAccessory {
            caption
        } trailing: {
            // `.secondary` 다 — brand 채움은 "여기서 무언가 만들어진다"는 신호인데,
            // 입출금 기록은 다른 화면으로 옮겨 갈 뿐 아무것도 생성하지 않는다.
            AccessoryActionButton(
                Constants.cashFlowTitle,
                systemImageName: Constants.cashFlowSymbolName,
                style: .secondary,
                action: onShowCashFlow
            )
        }
    }

    /// 종목이 없을 때는 셀 것이 없다는 사실만 말한다. 옆 컨트롤이 입출금 기록이라
    /// "첫 종목을 추가해 보세요" 류의 유도 문구를 두면 바로 옆 버튼을 가리키는 말로 읽힌다.
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

    private var holdingCountText: String {
        "\(viewModel.visibleHoldingCount)\(Constants.holdingCountUnit)"
    }
}

fileprivate enum Constants {
    static let cashFlowTitle = "입출금 기록"
    static let cashFlowSymbolName = "arrow.left.arrow.right"
    static let emptyCaption = "아직 종목이 없어요"
    static let holdingCountUnit = "종목"
    static let captionSeparator = "· "
    static let captionSuffix = " 기준"
}
