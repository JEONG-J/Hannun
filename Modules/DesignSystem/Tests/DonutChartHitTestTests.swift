//
//  DonutChartHitTestTests.swift
//  HannunDesignSystemTests
//
//  Created by euijjang97 on 8/3/26.
//

import Foundation
import HannunCore
import Testing
@testable import HannunDesignSystem

@Suite("DonutChart 히트 테스트")
struct DonutChartHitTestTests {

    // MARK: - Property

    /// 12시부터 시계방향으로 40% / 30% / 20% / 10%.
    private let slices: [DonutChartSlice] = [
        .init(category: .domesticStock, name: "국내주식", amount: .krw(40)),
        .init(category: .overseasStock, name: "해외주식", amount: .krw(30)),
        .init(category: .etf, name: "ETF", amount: .krw(20)),
        .init(category: .crypto, name: "코인", amount: .krw(10)),
    ]

    private let size = CGSize(width: 200, height: 200)

    // MARK: - Function

    /// 중심에서 각도 `turn`(한 바퀴 = 1) 만큼 시계방향으로 돌아간 지점.
    private func point(atTurn turn: Double, radius: CGFloat) -> CGPoint {
        let radians = turn * 2 * Double.pi
        return CGPoint(
            x: size.width / 2 + radius * sin(radians),
            y: size.height / 2 - radius * cos(radians)
        )
    }

    private func category(atTurn turn: Double, radius: CGFloat = 90) -> AssetCategory? {
        DonutChart.category(at: point(atTurn: turn, radius: radius), in: size, slices: slices)
    }

    @Test("12시 바로 다음은 첫 섹터다")
    func startsAtTwelveOClock() {
        #expect(category(atTurn: 0.01) == .domesticStock)
    }

    @Test("각 섹터의 한가운데를 짚으면 그 섹터가 나온다")
    func resolvesSectorMidpoints() {
        #expect(category(atTurn: 0.20) == .domesticStock)
        #expect(category(atTurn: 0.55) == .overseasStock)
        #expect(category(atTurn: 0.80) == .etf)
        #expect(category(atTurn: 0.95) == .crypto)
    }

    @Test("경계 앞뒤는 서로 다른 섹터다")
    func splitsAtSectorBoundary() {
        #expect(category(atTurn: 0.39) == .domesticStock)
        #expect(category(atTurn: 0.41) == .overseasStock)
    }

    /// 홀에는 안내 문구가 들어간다. 여기서 섹터가 잡히면 문구를 읽으려던 손이 선택을 바꾼다.
    @Test("가운데 홀은 아무 섹터도 아니다")
    func ignoresCenterHole() {
        #expect(category(atTurn: 0.20, radius: 0) == nil)
        #expect(category(atTurn: 0.20, radius: 50) == nil)
    }

    @Test("링 바깥은 아무 섹터도 아니다")
    func ignoresOutsideRing() {
        #expect(category(atTurn: 0.20, radius: 120) == nil)
    }

    @Test("금액이 하나도 없으면 어디를 눌러도 잡히지 않는다")
    func ignoresEmptySlices() {
        let point = CGPoint(x: 100, y: 20)

        #expect(DonutChart.category(at: point, in: size, slices: []) == nil)
        #expect(
            DonutChart.category(
                at: point,
                in: size,
                slices: [.init(category: .cash, name: "현금", amount: .krw(0))]
            ) == nil
        )
    }
}
