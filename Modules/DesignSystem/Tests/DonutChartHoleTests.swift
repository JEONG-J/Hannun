//
//  DonutChartHoleTests.swift
//  HannunDesignSystemTests
//
//  Created by euijjang97 on 8/4/26.
//

import Foundation
import HannunCore
import SwiftUI
import Testing
import UIKit
@testable import HannunDesignSystem

/// 중앙 홀은 지름이 시안값에 묶여 있어 글이 넘치면 늘릴 데가 없다. 그래서 "넘치지 않는다"를
/// 눈으로 확인하는 대신 실제 폰트 지표로 잰다 — 프리뷰는 회귀를 막아 주지 못한다.
///
/// 재는 크기는 홀 상한(`maximumTypeSize`) 하나다. 글은 크기가 커질수록만 넓어지므로
/// 상한에서 들어가면 그 아래는 전부 들어간다.
@Suite("도넛 중앙 홀 표기")
struct DonutChartHoleTests {

    // MARK: - Property

    /// 홀이 덮어야 하는 구간 전부. 접기 경계(원화 100만 / 달러 1,000) 앞뒤와, 이슈에 올라온
    /// 실제 값(`₩13,371,000`), 그리고 `narrow` 가 여덟 자를 보장하는 위쪽 끝을 함께 넣는다.
    private let amounts: [Money] = [
        .krw(0), .krw(999_999), .krw(1_000_000), .krw(1_234_567), .krw(9_876_543),
        .krw(13_371_000), .krw(99_996_000), .krw(134_371_000), .krw(1_234_567_890),
        .krw(-1_234_567_890), .krw(9_876_543_210_000),
        .usd(0.99), .usd(999.99), .usd(96_412.50), .usd(1_234_567.89), .usd(-98_765_432.10),
    ]

    private var contentSizeCategory: UIContentSizeCategory {
        UIContentSizeCategory(DonutChartHoleLayout.maximumTypeSize)
    }

    /// `.rowAmount` — `.headline` semibold 에 tabular 를 물린 것.
    private var amountFont: UIFont {
        font(.headline, weight: .semibold, monospacedDigits: true)
    }

    /// `.caption` — `.footnote` regular.
    private var captionFont: UIFont {
        font(.footnote, weight: .regular, monospacedDigits: false)
    }

    // MARK: - Function

    private func font(
        _ style: UIFont.TextStyle,
        weight: UIFont.Weight,
        monospacedDigits: Bool
    ) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory)
        let preferred = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        var descriptor = preferred.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])

        if monospacedDigits {
            let feature: [UIFontDescriptor.FeatureKey: Int] = [
                .type: kNumberSpacingType,
                .selector: kMonospacedNumbersSelector,
            ]
            descriptor = descriptor.addingAttributes([.featureSettings: [feature]])
        }

        return UIFont(descriptor: descriptor, size: 0)
    }

    private func width(_ text: String, _ font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// 캡션 한 줄 + 간격 + 금액 한 줄.
    private var valueBlockHeight: CGFloat {
        captionFont.lineHeight + .spacingXS + amountFont.lineHeight
    }

    // MARK: - 폭

    /// 이 이슈의 통과 기준이다 — 어떤 금액도 말줄임으로 끝나지 않는다.
    @Test("접은 금액은 어느 구간에서도 홀 폭 안에 들어간다")
    func narrowAmountsFitHoleWidth() {
        for money in amounts {
            let text = AmountFormatter.narrow(money)
            let measured = width(text, amountFont)

            #expect(
                measured <= DonutChartHoleLayout.valueContentWidth,
                "\(text) 가 \(measured)pt 로 홀 폭 \(DonutChartHoleLayout.valueContentWidth)pt 를 넘는다"
            )
        }
    }

    /// 접기 전 표기가 왜 안 되는지 — 폭 상한을 다시 좁히거나 축약을 되돌리면 여기서 걸린다.
    @Test("전체 자릿수 표기는 백만 원대부터 홀을 넘는다")
    func fullDigitsOverflowFromMillion() {
        #expect(width("₩999,999", amountFont) <= DonutChartHoleLayout.valueContentWidth)
        #expect(width("₩1,000,000", amountFont) > DonutChartHoleLayout.valueContentWidth)
        #expect(width("₩13,371,000", amountFont) > DonutChartHoleLayout.valueContentWidth)
    }

    /// `narrow` 는 억에서 단위를 멈추므로 억 자릿수가 다섯을 넘으면 표기가 아홉 자가 된다.
    /// 개인 자산 앱의 사정권 밖이라 조 단위를 들이지 않기로 한 선택인데, 그 선택이 어디서
    /// 끝나는지는 적어 둔다 — 언젠가 이 줄이 걸리면 그때는 단위를 하나 더 올려야 한다.
    @Test("여덟 자 보장은 원화 10조에서 끝난다")
    func narrowGuaranteeEndsAtTenTrillion() {
        #expect(AmountFormatter.narrow(.krw(9_999_900_000_000)) == "₩99,999억")
        #expect(width("₩99,999억", amountFont) <= DonutChartHoleLayout.valueContentWidth)

        #expect(AmountFormatter.narrow(.krw(10_000_000_000_000)) == "₩100,000억")
        #expect(width("₩100,000억", amountFont) > DonutChartHoleLayout.valueContentWidth)
    }

    /// 금액과 같은 `lineLimit(1)` 아래 있는 줄이라 함께 잰다.
    @Test("카테고리 이름도 홀 폭 안에 들어간다")
    func categoryTitlesFitHoleWidth() {
        for category in AssetCategory.allCases {
            let measured = width(category.title, captionFont)

            #expect(
                measured <= DonutChartHoleLayout.valueContentWidth,
                "\(category.title) 가 \(measured)pt 로 홀 폭을 넘는다"
            )
        }
    }

    // MARK: - 원 안에 머무르는지

    /// 폭 상한은 "블록 높이가 이만큼"이라는 전제 위에서 계산한 값이다. OS 가 폰트 지표를
    /// 키워 블록이 더 두꺼워지면 그 전제가 깨지고 상한도 같이 틀어진다.
    @Test("값 블록 높이는 폭 계산이 전제한 높이를 넘지 않는다")
    func valueBlockStaysWithinAssumedHeight() {
        #expect(valueBlockHeight / 2 <= DonutChartHoleLayout.valueContentHalfHeight)
    }

    /// 폭·높이를 따로 지키는 것만으로는 부족하다 — 원 안에서 실제로 위험한 건 블록의 **모서리**다.
    @Test("가장 넓은 금액을 넣어도 블록 모서리가 링을 파고들지 않는다")
    func widestValueBlockStaysInsideHole() {
        let widest = amounts
            .map { width(AmountFormatter.narrow($0), amountFont) }
            .max() ?? 0
        let corner = (pow(widest / 2, 2) + pow(valueBlockHeight / 2, 2)).squareRoot()

        #expect(corner <= DonutChartHoleLayout.radius, "모서리가 중심에서 \(corner)pt 로 밀려난다")
    }

    /// 힌트는 폭을 넓히면 문구가 두 줄로 붙으면서 오히려 모서리가 밖으로 밀려난다.
    /// 값 블록의 폭을 그대로 물려주면 안 되는 이유가 이것이다.
    @Test("힌트는 제 폭 안에서 링을 파고들지 않는다")
    func hintStaysInsideHole() {
        let hint = "눌러서 자산군별 보기" as NSString
        let bounds = hint.boundingRect(
            with: CGSize(
                width: DonutChartHoleLayout.hintContentWidth,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: captionFont],
            context: nil
        )
        let blockHeight = amountFont.lineHeight + .spacingXS + bounds.height
        let corner = (pow(bounds.width / 2, 2) + pow(blockHeight / 2, 2)).squareRoot()

        #expect(corner <= DonutChartHoleLayout.radius, "모서리가 중심에서 \(corner)pt 로 밀려난다")
    }

    // MARK: - 접근성

    /// 표기를 접는 건 폭이 없어서지 값을 줄이자는 게 아니다. 귀로 듣는 쪽은 전부 들어야 한다.
    @Test("VoiceOver 는 접지 않은 전체 금액을 읽는다")
    @MainActor
    func accessibilityValueReadsFullAmount() {
        let slice = DonutChartSlice(
            category: .domesticStock,
            name: "국내주식",
            amount: .krw(1_234_567_890)
        )
        let chart = DonutChart(slices: [slice], selection: .constant(.domesticStock))

        #expect(chart.accessibilityValue == "국내주식, ₩1,234,567,890")
    }

    @Test("고른 섹터가 없으면 선택 안 함으로 읽는다")
    @MainActor
    func accessibilityValueReportsEmptySelection() {
        let slice = DonutChartSlice(category: .cash, name: "현금", amount: .krw(1_000))
        let chart = DonutChart(slices: [slice], selection: .constant(nil))

        #expect(chart.accessibilityValue == "선택 안 함")
    }
}
