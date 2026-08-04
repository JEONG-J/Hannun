//
//  JournalComposeAccessory.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import SwiftUI

/// 매매일지 탭의 하단 액세서리 — 작성 하나 (JR-2).
///
/// 목록 상태("이번 달 7건")는 큰 제목 아래 `navigationSubtitle` 로 옮겼다. 그 줄은 지금 무엇을
/// 보고 있는지를 말하는 **제목의 일부**라서, 화면 반대쪽 끝에 떼어 놓으면 제목과 눈이 두 번
/// 오간다. 남은 동작이 작성 하나뿐이므로 캡슐째 버튼으로 쓴다 — 오른쪽 알약 하나만 눌리게
/// 두면 좁은 과녁을 위해 캡슐 나머지가 죽는다 (`BottomAccessory` 규칙).
///
/// 캡슐이 이미 버튼이라 안에는 알약을 겹치지 않는다. `AccessoryActionButton` 을 넣으면
/// 버튼 안의 버튼이 되고, 채운 알약이 캡슐 안에 캡슐로 한 겹 더 쌓인다.
struct JournalComposeAccessory: View {

    // MARK: - Property

    @Environment(\.accessoryLayout) private var layout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let onCompose: () -> Void

    // MARK: - Body

    init(onCompose: @escaping () -> Void) {
        self.onCompose = onCompose
    }

    var body: some View {
        Button(action: onCompose) {
            BottomAccessory {
                composeLabel
            }
            // 캡슐 전체가 과녁이 되려면 둘 다 필요하다 — 버튼의 히트 영역은 라벨이 그린
            // 픽셀이라, 없으면 글자 주변 빈 자리가 눌리지 않는다.
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Constants.composeTitle)
    }

    // MARK: - Function

    private var composeLabel: some View {
        HStack(spacing: .spacingXS) {
            Image(systemName: Constants.composeSymbolName)
                .imageScale(.small)

            Text(title)
                .lineLimit(1)
        }
        .hannunFont(.pillLabel)
        .foregroundStyle(Color.brand)
        .frame(maxWidth: .infinity, minHeight: .minimumTouchTarget)
    }

    /// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 이 탭의 유일한 진입점이라
    /// 라벨이 잘리게 두는 대신 짧은 쪽으로 바꾼다.
    private var title: String {
        layout == .inline || dynamicTypeSize.isAccessibilitySize
            ? Constants.inlineComposeTitle
            : Constants.composeTitle
    }
}

fileprivate enum Constants {
    static let composeTitle = "매매일지 작성"
    static let inlineComposeTitle = "작성"
    static let composeSymbolName = "pencil.line"
}
