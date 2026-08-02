//
//  AccessoryCaption.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 액세서리 캡슐 왼쪽에 놓는 보조 문구. 상태를 말하거나(갱신 시각) 다음 행동을 권한다(작성 힌트).
///
/// 옆 컨트롤을 밀어내지 않는 것이 이 컴포넌트의 일이다. 캡슐 폭이 모자랄 때 먼저 양보하는 쪽은
/// 항상 문구여야 하며 — 오른쪽 버튼이 잘리면 그 탭의 유일한 진입점이 사라진다 — 그래서
/// 한 줄로 자르고 그래도 넘치면 줄여서 담는다.
///
/// 아이콘은 받지 않는다 — 캡션 무아이콘이 규칙이다. 눌리지 않는 `arrow.clockwise` 같은
/// 어포던스 거짓말을 막고, "아이콘이 있으면 컨트롤"이라는 구분 신호를 지키기 위해서다.
///
/// 값(시각·수치)이 있는 문구는 2톤으로 쓴다 — 정보가치가 있는 값만 진하게, 부속어는 흐리게.
/// 단일 `Text` 연결이라 VoiceOver 는 한 요소로 읽고, 폭 축소도 한 덩어리로 된다.
public struct AccessoryCaption: View {

    // MARK: - Property

    private let value: String?
    private let text: String

    // MARK: - Body

    public init(_ text: String) {
        value = nil
        self.text = text
    }

    /// - Parameters:
    ///   - value: 진하게 강조할 값 (예: "12:04"). tabular 숫자로 그린다.
    ///   - suffix: 뒤따르는 부속어 (예: "시세 기준").
    public init(value: String, suffix: String) {
        self.value = value
        text = suffix
    }

    public var body: some View {
        caption
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumScaleFactor)
            .accessibilityElement(children: .combine)
    }

    // MARK: - Function

    private var caption: Text {
        guard let value else {
            return Text(text)
                .font(.hannun(.caption))
                .foregroundStyle(Color.textSecondary)
        }

        let valueText = Text(value)
            .font(.hannun(.caption, tabularFigures: true).weight(.semibold))
            .foregroundStyle(Color.textPrimary)
        let suffixText = Text(text)
            .font(.hannun(.caption))
            .foregroundStyle(Color.textSecondary)
        return Text("\(valueText) \(suffixText)")
    }
}

fileprivate enum Constants {
    /// 문구가 넘칠 때 여기까지만 줄인다. 더 줄이면 캡션(13pt)이 읽기 어려워진다.
    static let minimumScaleFactor: CGFloat = 0.9
}

#if DEBUG
private struct AccessoryCaptionPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            labeled("2톤 — 값만 진하게") {
                AccessoryCaption(value: "12:04", suffix: "시세 기준")
            }

            labeled("2톤 · 축약 문구") {
                AccessoryCaption(value: "12:04", suffix: "기준")
            }

            labeled("1톤 — 값이 없는 문구") {
                AccessoryCaption("시세 불러오는 중")
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private func labeled(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textPrimary)

            content()
        }
    }
}

#Preview("액세서리 캡션 · 라이트") {
    AccessoryCaptionPreview()
        .preferredColorScheme(.light)
}

#Preview("액세서리 캡션 · 다크") {
    AccessoryCaptionPreview()
        .preferredColorScheme(.dark)
}
#endif
