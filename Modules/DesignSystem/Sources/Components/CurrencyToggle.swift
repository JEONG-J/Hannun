//
//  CurrencyToggle.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// KRW / USD 전환 세그먼트. 순자산 탭 하단 액세서리 안에 놓인다.
///
/// 액세서리 캡슐 위이므로 glass 를 겹치지 않는다 — 그래서 `FilterChip` 의 `.accessory` 표면을
/// 그대로 재사용한다. 세그먼트를 따로 그리면 같은 규칙이 두 벌이 된다.
public struct CurrencyToggle: View {

    // MARK: - Property

    @Binding private var selection: Currency

    // MARK: - Body

    public init(selection: Binding<Currency>) {
        _selection = selection
    }

    public var body: some View {
        ChipGroup(appearance: .accessory, scrollsHorizontally: false) {
            ForEach(Currency.allCases, id: \.self) { currency in
                FilterChip(currency.rawValue, isSelected: currency == selection) {
                    selection = currency
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Constants.accessibilityLabel)
    }
}

fileprivate enum Constants {
    static let accessibilityLabel = "표시 통화"
}

#if DEBUG
private struct CurrencyTogglePreview: View {

    // MARK: - Property

    @State private var selection: Currency = .krw

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingXL) {
            AmountText(
                selection == .krw ? .krw(128_450_000) : .usd(96_412.50),
                size: .display
            )

            BottomAccessory {
                AccessoryCaption("오후 12:04 시세 기준")
            } trailing: {
                CurrencyToggle(selection: $selection)
            }
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("통화 토글 · 라이트") {
    CurrencyTogglePreview()
        .preferredColorScheme(.light)
}

#Preview("통화 토글 · 다크") {
    CurrencyTogglePreview()
        .preferredColorScheme(.dark)
}
#endif
