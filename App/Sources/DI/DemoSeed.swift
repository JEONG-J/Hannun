//
//  DemoSeed.swift
//  Hannun
//
//  Created by euijjang97 on 8/1/26.
//

#if DEBUG
import Foundation
import HannunCore
import HannunDomain
import SwiftData

/// 신규 설치 상태의 시뮬레이터에서는 네 탭이 전부 빈 화면이라 레이아웃·색 규칙을 눈으로 볼 수 없다.
/// `-seed-demo` 실행 인자를 줬을 때만 켜지는 디버그 전용 표본 데이터다.
enum DemoSeed {
    // MARK: - Function

    static func seedIfRequested(_ container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains(Constants.launchArgument) else { return }

        let context = ModelContext(container)
        // 실행할 때마다 다시 넣으면 합계가 부풀어 화면 검증이 무의미해진다.
        guard isStoreEmpty(context) else { return }

        let holdingsByTicker = insertHoldings(into: context)
        insertCashFlows(into: context)
        insertSnapshots(into: context)
        insertJournalEntries(into: context, taggedWith: holdingsByTicker)

        do {
            try context.save()
        } catch {
            assertionFailure("데모 시드를 저장하지 못했습니다. \(error)")
        }
    }

    /// 조회 자체가 실패하면 비어 있는지 알 수 없으므로 넣지 않는 쪽을 택한다.
    private static func isStoreEmpty(_ context: ModelContext) -> Bool {
        guard let count = try? context.fetchCount(FetchDescriptor<Holding>()) else { return false }
        return count == 0
    }

    /// 상승 빨강·하락 파랑 규칙을 한 화면에서 확인하려고 손실 종목(비트코인)을 섞어 둔다.
    ///
    /// 현재가를 `manualPrice` 로 고정하는 이유는 시세 폴백 순서 때문이다 — 시뮬레이터에서
    /// KIS·업비트 응답이 비면 평단가로 내려가서 손익이 전부 0 으로 보인다.
    private static func insertHoldings(into context: ModelContext) -> [String: Holding] {
        let records: [HoldingRecord] = [
            HoldingRecord(
                category: .cash,
                name: "수시입출금",
                quantity: 4_820_000,
                createdAt: date(2026, 1, 2),
                updatedAt: date(2026, 1, 2)
            ),
            HoldingRecord(
                category: .domesticStock,
                name: "삼성전자",
                ticker: Constants.samsungElectronicsTicker,
                quantity: 120,
                averagePrice: 71_500,
                manualPrice: 84_300,
                createdAt: date(2026, 1, 8),
                updatedAt: date(2026, 7, 30)
            ),
            HoldingRecord(
                category: .overseasStock,
                name: "Apple",
                ticker: Constants.appleTicker,
                currency: .usd,
                quantity: 18,
                averagePrice: 214.60,
                manualPrice: 246.20,
                createdAt: date(2026, 2, 14),
                updatedAt: date(2026, 7, 30)
            ),
            HoldingRecord(
                category: .etf,
                name: "TIGER 미국S&P500",
                ticker: Constants.tigerUSLargeCapTicker,
                quantity: 310,
                averagePrice: 18_940,
                manualPrice: 21_650,
                createdAt: date(2026, 1, 20),
                updatedAt: date(2026, 7, 30)
            ),
            HoldingRecord(
                category: .crypto,
                name: "비트코인",
                ticker: Constants.bitcoinTicker,
                quantity: 0.0412,
                averagePrice: 96_400_000,
                manualPrice: 88_200_000,
                createdAt: date(2026, 3, 3),
                updatedAt: date(2026, 7, 30)
            ),
        ]

        var holdingsByTicker: [String: Holding] = [:]
        for record in records {
            let holding = Holding(record: record)
            context.insert(holding)
            holdingsByTicker[holding.ticker] = holding
        }
        return holdingsByTicker
    }

    /// 입출금이 있어야 YTD 수익률이 "순수 투자 성과"와 다른 값으로 갈라져 계산을 확인할 수 있다.
    private static func insertCashFlows(into context: ModelContext) {
        let records = [
            CashFlowRecord(
                occurredOn: date(2026, 2, 5),
                amount: 3_000_000,
                kind: .deposit,
                memo: "2월 적립"
            ),
            CashFlowRecord(
                occurredOn: date(2026, 5, 11),
                amount: 1_200_000,
                kind: .withdrawal,
                memo: "비상금 인출"
            ),
        ]

        for record in records {
            context.insert(CashFlowEvent(record: record))
        }
    }

    /// YTD 는 연초 스냅샷을 기준값으로 잡고, 추이 차트는 점이 2개 이상이어야 선이 그려진다.
    /// 그래서 1월 1일부터 매월 1일까지 채우고 중간에 하락 구간도 둔다.
    private static func insertSnapshots(into context: ModelContext) {
        let monthlyTotals: [(month: Int, total: Decimal)] = [
            (1, 38_400_000),
            (2, 41_900_000),
            (3, 40_150_000),
            (4, 43_720_000),
            (5, 42_080_000),
            (6, 45_310_000),
            (7, 47_960_000),
        ]

        for (month, total) in monthlyTotals {
            let record = NetWorthRecord(
                recordedOn: date(2026, month, 1),
                totalInKRW: .krw(total),
                totalInUSD: .usd(total / Constants.usdToKRWRate),
                categorySubtotals: Constants.categoryWeights.map {
                    CategorySubtotal(category: $0.category, amount: total * $0.percent / 100)
                }
            )
            context.insert(NetWorthSnapshot(record: record))
        }
    }

    private static func insertJournalEntries(
        into context: ModelContext,
        taggedWith holdingsByTicker: [String: Holding]
    ) {
        let entries: [(ticker: String, record: JournalRecord)] = [
            (
                Constants.samsungElectronicsTicker,
                JournalRecord(
                    writtenAt: date(2026, 7, 28),
                    title: "삼성전자 추가 매수",
                    content: "실적 발표 이후 조정에서 20주 더 담았다. 평단이 내려가서 심리적으로 편해졌다.",
                    updatedAt: date(2026, 7, 28)
                )
            ),
            (
                Constants.bitcoinTicker,
                JournalRecord(
                    writtenAt: date(2026, 6, 14),
                    title: "비트코인 비중 점검",
                    content: "전체의 8% 수준. 변동성 대비 감당 가능한 범위라 당분간 추가 매수는 보류한다.",
                    updatedAt: date(2026, 6, 14)
                )
            ),
            (
                Constants.appleTicker,
                JournalRecord(
                    writtenAt: date(2026, 4, 2),
                    title: "환율 부담에도 AAPL 유지",
                    content: "원달러가 높아 신규 진입은 미루되, 이미 산 물량은 환헤지 없이 그대로 간다.",
                    updatedAt: date(2026, 4, 2)
                )
            ),
        ]

        for (ticker, record) in entries {
            let entry = JournalEntry(record: record)
            context.insert(entry)
            // `JournalEntry.init(record:)` 는 식별자만 받고 관계는 채우지 않는다.
            // Repository 와 마찬가지로 모델 인스턴스를 직접 물려야 종목 태그가 붙는다.
            entry.holdings = holdingsByTicker[ticker].map { [$0] }
        }
    }

    /// 성과·추이 계산이 모두 `Calendar.current` 를 쓰므로 시드도 같은 달력의 자정에 맞춘다.
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: components) ?? Date()
    }
}

fileprivate enum Constants {
    static let launchArgument: String = "-seed-demo"

    static let samsungElectronicsTicker: String = "005930"
    static let appleTicker: String = "AAPL"
    static let tigerUSLargeCapTicker: String = "360750"
    static let bitcoinTicker: String = "BTC"

    /// 스냅샷의 달러 환산에만 쓰는 고정 환율 — 시드는 네트워크 응답에 기대지 않는다.
    static let usdToKRWRate: Decimal = 1_380

    /// 스냅샷 카테고리 소계의 구성비(%). 합이 100 이라 총액을 그대로 쪼갤 수 있다.
    static let categoryWeights: [(category: AssetCategory, percent: Decimal)] = [
        (.cash, 10),
        (.domesticStock, 21),
        (.overseasStock, 27),
        (.etf, 34),
        (.crypto, 8),
    ]
}
#endif
