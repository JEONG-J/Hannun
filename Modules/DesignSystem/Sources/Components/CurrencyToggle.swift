//
//  CurrencyToggle.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// KRW / USD 전환 세그먼트. **입력 폼 전용**이다 — 종목·입출금 편집 화면에서 방금 적는 금액의
/// 통화를 고를 때 쓴다.
///
/// 하단 액세서리에는 넣지 않는다. 캡슐 오른쪽은 컨트롤 **하나**의 자리인데 세그먼트는 그 안에
/// 선택지를 둘 이상 펼쳐 놓아 규칙이 깨지고, 두 칸 중 한 칸은 늘 "이미 그 상태"라 아무 일도
/// 하지 않는 버튼이 된다. 순자산 탭은 대신 캡슐 전체를 눌러 두 통화를 오간다.
///
/// 카드 표면 위이므로 glass 를 겹치지 않는다 — 그래서 `FilterChip` 의 `.accessory` 표면을
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
        VStack(alignment: .leading, spacing: .spacingM) {
            Text("통화")
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            CurrencyToggle(selection: $selection)

            AmountText(
                selection == .krw ? .krw(128_450_000) : .usd(96_412.50),
                size: .display
            )
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
