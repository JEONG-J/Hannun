//
//  Font+Hannun.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

/// UI 스펙 타이포 스케일. 시스템 폰트(SF Pro)만 쓴다 — 시안의 `Inter` 는 Pencil 에
/// SF Pro 가 없어 대체된 것이라 따라가지 않는다.
///
/// `tabLabel` 을 뺀 모든 토큰은 기본 크기가 같은 시스템 `Font.TextStyle` 위에 얹혀 있다
/// (34/28/20/17/15/13 이 largeTitle/title/title3/headline·body/subheadline/footnote 의
/// 기본 크기와 정확히 일치). 고정 pt 대신 이 방식을 쓰면 Dynamic Type 이 그대로 따라온다.
public enum HannunTextStyle: String, CaseIterable, Sendable {
    case displayAmount
    case screenTitle
    case sectionHeading
    case rowTitle
    case rowAmount
    case body
    case subtext
    case caption
    case pillLabel
    case tabLabel
}

public extension HannunTextStyle {
    /// tabular 가 **필수**인 스타일은 `monospacedDigit` 을 미리 물려 둔다.
    /// 숫자일 때만 tabular 인 `subtext`/`caption` 은 `Font.hannun(_:tabularFigures:)` 로 켠다.
    var font: Font {
        switch self {
        case .displayAmount: .system(.largeTitle, weight: .bold).monospacedDigit()
        case .screenTitle: .system(.title, weight: .bold)
        case .sectionHeading: .system(.title3, weight: .semibold)
        case .rowTitle: .system(.headline, weight: .semibold)
        case .rowAmount: .system(.headline, weight: .semibold).monospacedDigit()
        case .body: .system(.body, weight: .regular)
        case .subtext: .system(.subheadline, weight: .regular)
        case .caption: .system(.footnote, weight: .regular)
        case .pillLabel: .system(.footnote, weight: .semibold).monospacedDigit()
        case .tabLabel: .system(size: Constants.tabLabelSize, weight: .semibold)
        }
    }

    /// 큰 금액만 자간을 소폭 좁힌다.
    var tracking: CGFloat {
        self == .displayAmount ? Constants.displayAmountTracking : 0
    }
}

public extension Font {
    /// - Parameter tabularFigures: `subtext`/`caption` 처럼 "숫자일 때만" tabular 인 스타일에
    ///   숫자를 담을 때 켠다. 이미 tabular 가 고정된 스타일에는 영향이 없다.
    static func hannun(_ style: HannunTextStyle, tabularFigures: Bool = false) -> Font {
        tabularFigures ? style.font.monospacedDigit() : style.font
    }
}

public extension View {
    /// 폰트와 자간을 함께 적용한다. `Font` 값만 필요하면 `Font.hannun(_:tabularFigures:)` 를 쓴다.
    func hannunFont(_ style: HannunTextStyle, tabularFigures: Bool = false) -> some View {
        font(.hannun(style, tabularFigures: tabularFigures))
            .tracking(style.tracking)
    }
}

fileprivate enum Constants {
    /// 시스템 탭바 관례를 따르는 토큰 밖 크기. 대응하는 TextStyle 이 없어 유일하게 고정 pt 다.
    static let tabLabelSize: CGFloat = 10
    static let displayAmountTracking: CGFloat = -0.4
}

#if DEBUG
private struct TypographyTokenPreview: View {

    // MARK: - Property

    private let sampleAmount = "₩128,450,000"

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingL) {
                ForEach(HannunTextStyle.allCases, id: \.self) { style in
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text(style.rawValue)
                            .hannunFont(.caption)
                            .foregroundStyle(Color.textSecondary)

                        Text(sampleAmount)
                            .hannunFont(style, tabularFigures: true)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacingL)
        }
        .background(Color.backgroundPrimary)
    }
}

#Preview("타이포 토큰 · 라이트") {
    TypographyTokenPreview()
        .preferredColorScheme(.light)
}

#Preview("타이포 토큰 · 다크") {
    TypographyTokenPreview()
        .preferredColorScheme(.dark)
}
#endif
