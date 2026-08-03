//
//  PortfolioActionAccessory.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunDesignSystem
import SwiftUI

/// 포트폴리오 탭의 하단 액세서리 — 목록 상태 한 줄 + 종목 추가 하나 (PF-2).
///
/// 예전에는 여기에 입출금 기록까지 두 개를 나란히 놓았지만, 캡슐 오른쪽은 컨트롤 하나의
/// 자리다. 라벨 두 개는 축약 상태에서 들어가지 않아 Menu 로 접어야 했고, 접는 순간
/// "누르면 바로 되는 것"이던 액션이 "눌러서 고르는 것"으로 성격이 바뀌었다. 입출금 기록은
/// 목록 화면 툴바로 돌려보냈다 — 캡슐에 남은 종목 추가와 빈도가 다르고, 툴바는 축약되지
/// 않는다 (디자인 문서 §4.2 · §11-1).
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
    private let onAddHolding: () -> Void

    // MARK: - Body

    init(viewModel: PortfolioListViewModel, onAddHolding: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onAddHolding = onAddHolding
    }

    var body: some View {
        BottomAccessory {
            caption
        } trailing: {
            AccessoryActionButton(
                Constants.addHoldingTitle,
                systemImageName: Constants.addHoldingSymbolName,
                action: onAddHolding
            )
        }
    }

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
    static let addHoldingTitle = "종목 추가"
    static let addHoldingSymbolName = "plus"
    static let emptyCaption = "첫 종목을 추가해 보세요"
    static let holdingCountUnit = "종목"
    static let captionSeparator = "· "
    static let captionSuffix = " 기준"
}
