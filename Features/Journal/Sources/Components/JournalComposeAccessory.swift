//
//  JournalComposeAccessory.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import SwiftUI

/// 매매일지 탭의 하단 액세서리 — 목록 상태 한 줄 + 작성 하나 (JR-2).
///
/// 왼쪽은 기록이 없을 때만 CTA 로 말하고, 한 건이라도 쌓이면 **이번 달 몇 건**인지로 바뀐다.
/// "오늘의 매매를 기록해보세요"를 계속 띄우면 이미 쓰고 있는 사람에게는 아무 정보도 주지
/// 않는 장식이 된다. 필터·검색이 걸려 있으면 지금 무엇을 보고 있는지를 대신 말한다
/// (디자인 문서 §4.0).
///
/// 이 탭에는 스크롤로 밀려 나가는 히어로가 없다 — 큰 숫자 없이 목록으로 시작하므로
/// 교대할 상대가 없다 (디자인 문서 §6).
///
/// 값이 아니라 ViewModel 을 받는다 — 액세서리 클로저는 첫 등장 시점에 붙잡히므로 값을
/// 꺼내 넘기면 그 시점에 굳는다.
struct JournalComposeAccessory: View {

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let viewModel: JournalListViewModel
    private let onCompose: () -> Void

    // MARK: - Body

    init(viewModel: JournalListViewModel, onCompose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCompose = onCompose
    }

    var body: some View {
        BottomAccessory {
            caption
        } trailing: {
            composeButton
        }
    }

    // MARK: - Function

    @ViewBuilder
    private var caption: some View {
        switch viewModel.caption {
        case .none:
            AccessoryCaption(hintText)

        case .empty:
            AccessoryCaption(hintText)

        case let .filtered(name, count):
            AccessoryCaption(.plain(name), .value(countText(count)))

        case let .thisMonth(count):
            AccessoryCaption(.plain(Constants.thisMonthPrefix), .value(countText(count)))

        case let .total(count):
            AccessoryCaption(.plain(Constants.totalPrefix), .value(countText(count)))
        }
    }

    /// 축약에서는 아이콘 원형으로 줄이되 VoiceOver 라벨은 같은 의미를 유지한다.
    @ViewBuilder
    private var composeButton: some View {
        if layout == .inline {
            AccessoryActionButton(
                systemImageName: Constants.composeSymbolName,
                accessibilityLabel: Constants.composeAccessibilityLabel,
                action: onCompose
            )
        } else {
            AccessoryActionButton(
                Constants.composeTitle,
                systemImageName: Constants.composeSymbolName,
                action: onCompose
            )
        }
    }

    /// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 힌트는 빈 상태의 CTA 라
    /// 숨기는 대신 줄인다.
    private var hintText: String {
        layout == .inline || dynamicTypeSize.isAccessibilitySize
            ? Constants.inlineHintText
            : Constants.hintText
    }

    private func countText(_ count: Int) -> String {
        "\(count)\(Constants.countUnit)"
    }
}

fileprivate enum Constants {
    static let hintText = "오늘의 매매를 기록해보세요"
    static let inlineHintText = "매매 기록"
    static let thisMonthPrefix = "이번 달"
    static let totalPrefix = "전체"
    static let countUnit = "건"
    static let composeSymbolName = "pencil.line"
    static let composeTitle = "작성"
    static let composeAccessibilityLabel = "일지 작성"
}
