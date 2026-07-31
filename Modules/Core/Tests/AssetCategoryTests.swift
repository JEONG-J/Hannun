//
//  AssetCategoryTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 8/1/26.
//

import Testing
@testable import HannunCore

@Suite("AssetCategory 표시 어휘")
struct AssetCategoryDisplayTests {

    @Test("모든 분류에 표시 이름이 있다")
    func everyCategoryHasTitle() {
        for category in AssetCategory.allCases {
            #expect(!category.title.isEmpty)
        }
    }

    @Test(
        "수량 단위는 증권과 코인을 가른다",
        arguments: zip(
            AssetCategory.allCases,
            [nil, "주", "주", "주", "개"]
        )
    )
    func quantityUnitMatchesCategory(category: AssetCategory, expected: String?) {
        #expect(category.quantityUnit == expected)
    }

    @Test("현금만 수량 대신 잔액을 입력받는다")
    func onlyCashUsesBalanceFieldTitle() {
        #expect(AssetCategory.cash.quantityFieldTitle == "잔액")

        for category in AssetCategory.allCases where category != .cash {
            #expect(category.quantityFieldTitle == "수량")
        }
    }
}
