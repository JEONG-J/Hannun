//
//  AccessoryCaption.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 액세서리 캡슐 왼쪽에 놓는 **주어 한 줄**. 이 탭이 지금 무엇을 보고 있는지를 말한다.
///
/// 옆 컨트롤을 밀어내지 않는 것이 이 컴포넌트의 일이다. 캡슐 폭이 모자랄 때 먼저 양보하는 쪽은
/// 항상 문구여야 하며 — 오른쪽 버튼이 잘리면 그 탭의 유일한 진입점이 사라진다 — 그래서
/// 한 줄로 자르고 그래도 넘치면 줄여서 담는다.
///
/// 아이콘은 받지 않는다 — 캡션 무아이콘이 규칙이다. 눌리지 않는 `arrow.clockwise` 같은
/// 어포던스 거짓말을 막고, "아이콘이 있으면 컨트롤"이라는 구분 신호를 지키기 위해서다.
/// 예외는 둘뿐이고 둘 다 의미가 정해져 있다 — 범례 dot(`dotted(_:)`)과 확장 셰브런
/// (`expandable()`). 셰브런은 **누르면 실제로 열리는 대상이 있을 때만** 붙인다.
///
/// ## 문구는 조각으로 쓴다
///
/// 정보가치가 있는 값만 진하게, 부속어는 흐리게. 손익처럼 색이 의미인 값은 `accent` 로 준다.
/// 조각들은 단일 `Text` 로 연결되므로 VoiceOver 는 한 요소로 읽고 폭 축소도 한 덩어리로 된다.
///
/// ```swift
/// AccessoryCaption(.plain("S&P500 대비"), .accent("+1.4%p", .gain))
///     .dotted(.categoryForeign)
///     .expandable()
/// ```
public struct AccessoryCaption: View {

    /// 캡션을 이루는 한 조각. 위계는 웨이트와 색으로만 가른다.
    public enum Segment: Equatable, Sendable {
        /// 부속어 — Regular · `textSecondary`.
        case plain(String)
        /// 값 — Semibold · tabular · `textPrimary`.
        case value(String)
        /// 색이 곧 의미인 값(손익·초과수익) — Semibold · tabular · 지정 색.
        case accent(String, Color)
    }

    // MARK: - Property

    private let segments: [Segment]
    private var dotColor: Color?
    private var isExpandable = false

    // MARK: - Body

    public init(_ segments: Segment...) {
        self.segments = segments
    }

    public init(_ segments: [Segment]) {
        self.segments = segments
    }

    /// 값 없는 한 줄 문구 — "시세 불러오는 중".
    public init(_ text: String) {
        segments = [.plain(text)]
    }

    /// - Parameters:
    ///   - value: 진하게 강조할 값 (예: "12:04"). tabular 숫자로 그린다.
    ///   - suffix: 뒤따르는 부속어 (예: "시세 기준").
    public init(value: String, suffix: String) {
        segments = [.value(value), .plain(suffix)]
    }

    public var body: some View {
        HStack(spacing: .spacingXS) {
            if let dotColor {
                CategoryDot(color: dotColor)
                    .accessibilityHidden(true)
            }

            caption
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumScaleFactor)

            if isExpandable {
                Image(systemName: Constants.expandSymbolName)
                    .imageScale(.small)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Function

    /// 범례 dot 을 앞에 붙인다. 색이 카테고리·벤치마크를 가리킬 때만 쓴다.
    public func dotted(_ color: Color) -> Self {
        var copy = self
        copy.dotColor = color
        return copy
    }

    /// 확장 셰브런(`chevron.up`)을 뒤에 붙인다. **누르면 열리는 대상이 있을 때만** 쓴다 —
    /// 어포던스만 그려 놓고 아무 일도 없으면 그게 제일 나쁜 거짓말이다.
    public func expandable(_ isExpandable: Bool = true) -> Self {
        var copy = self
        copy.isExpandable = isExpandable
        return copy
    }

    private var caption: Text {
        segments.enumerated().reduce(Text("")) { joined, item in
            let piece = text(for: item.element)
            return item.offset == 0 ? piece : Text("\(joined) \(piece)")
        }
    }

    private func text(for segment: Segment) -> Text {
        switch segment {
        case let .plain(string):
            Text(string)
                .font(.hannun(.caption))
                .foregroundStyle(Color.textSecondary)
        case let .value(string):
            Text(string)
                .font(.hannun(.caption, tabularFigures: true).weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        case let .accent(string, color):
            Text(string)
                .font(.hannun(.caption, tabularFigures: true).weight(.semibold))
                .foregroundStyle(color)
        }
    }
}

fileprivate enum Constants {
    /// 문구가 넘칠 때 여기까지만 줄인다. 더 줄이면 캡션(13pt)이 읽기 어려워진다.
    static let minimumScaleFactor: CGFloat = 0.9
    /// 시트가 아래에서 올라오므로 위를 가리킨다.
    static let expandSymbolName = "chevron.up"
}

#if DEBUG
private struct AccessoryCaptionPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            labeled("2톤 — 값만 진하게") {
                AccessoryCaption(value: "12:04", suffix: "시세 기준")
            }

            labeled("1톤 — 값이 없는 문구") {
                AccessoryCaption("시세 불러오는 중")
            }

            labeled("accent — 색이 의미인 값") {
                AccessoryCaption(.value("₩8,420만"), .accent("+12.4%", .gain))
            }

            labeled("dot + 셰브런 — 확장 대상이 있을 때") {
                AccessoryCaption(.plain("S&P500 대비"), .accent("+1.4%p", .gain))
                    .dotted(.categoryForeign)
                    .expandable()
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
