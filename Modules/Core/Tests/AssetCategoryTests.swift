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

    /// `zip` 은 짧은 쪽에 맞춰 잘린다 — 분류가 늘면 이 배열도 같이 늘려야 뒤쪽이 검증된다.
    @Test(
        "수량 단위는 증권과 코인을 가른다",
        arguments: zip(
            AssetCategory.allCases,
            [nil, "주", "주", "주", "개", nil]
        )
    )
    func quantityUnitMatchesCategory(category: AssetCategory, expected: String?) {
        #expect(category.quantityUnit == expected)
    }

    @Test("잔액으로 끝나는 분류만 수량 대신 잔액을 입력받는다")
    func onlyBalanceOnlyCategoriesUseBalanceFieldTitle() {
        #expect(AssetCategory.cash.quantityFieldTitle == "잔액")
        #expect(AssetCategory.loan.quantityFieldTitle == "잔액")

        for category in AssetCategory.allCases where !category.isBalanceOnly {
            #expect(category.quantityFieldTitle == "수량")
        }
    }

    @Test("부채는 대출뿐이다")
    func onlyLoanIsLiability() {
        #expect(AssetCategory.allCases.filter(\.isLiability) == [.loan])
    }

    @Test("잔액만 받는 분류는 현금과 대출뿐이다")
    func onlyCashAndLoanAreBalanceOnly() {
        #expect(AssetCategory.allCases.filter(\.isBalanceOnly) == [.cash, .loan])
    }

    /// 선언 순서가 포트폴리오 카드 순서이자 동률 정렬 기준이다. 대출은 항상 맨 아래에 온다.
    @Test("대출이 마지막 분류다")
    func loanIsDeclaredLast() {
        #expect(AssetCategory.allCases.last == .loan)
    }
}
