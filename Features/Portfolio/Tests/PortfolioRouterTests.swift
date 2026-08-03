//
//  PortfolioRouterTests.swift
//  PortfolioFeatureTests
//
//  Created by euijjang97 on 8/3/26.
//

import Testing
@testable import PortfolioFeature

@MainActor
@Suite("포트폴리오 화면 전환")
struct PortfolioRouterTests {

    // MARK: - Function

    @Test("탭을 열면 종목 목록부터 보인다")
    func startsOnHoldings() {
        #expect(PortfolioRouter().route == .holdings)
    }

    /// 스택이 아니라 값 하나로 바뀌므로, 연타해도 같은 화면이 겹쳐 쌓이지 않고 그냥 되돌아온다.
    @Test("액세서리를 누를 때마다 두 화면을 오간다")
    func togglesBetweenBothScreens() {
        let router = PortfolioRouter()

        router.toggleRoute()
        #expect(router.route == .cashFlow)

        router.toggleRoute()
        #expect(router.route == .holdings)
    }

    /// 액세서리 오른쪽은 지금 있는 화면이 아니라 **갈 곳**을 적는다 — 입출금 기록으로 넘어가면
    /// "포트폴리오" 로 뒤집혀 돌아올 길이 여기라고 말한다.
    @Test("오른쪽 라벨은 갈 화면의 이름이다")
    func labelsTheCounterpart() {
        #expect(PortfolioRoute.holdings.counterpart.title == "입출금 기록")
        #expect(PortfolioRoute.cashFlow.counterpart.title == "포트폴리오")
    }
}
