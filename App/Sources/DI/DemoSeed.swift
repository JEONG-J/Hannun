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
///
/// 날짜는 전부 **오늘 기준 상대값**이다. 연·월을 박아 두면 시간이 지나는 만큼 시드가 과거로
/// 밀려 나가, 이번 달 캘린더가 비고 전일 대비 변동이 사라지고 YTD 기준일이 창 밖으로 나간다.
enum DemoSeed {
    // MARK: - Function

    static func seedIfRequested(_ container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains(Constants.launchArgument) else { return }

        let context = ModelContext(container)
        // 실행할 때마다 다시 넣으면 합계가 부풀어 화면 검증이 무의미해진다.
        guard isStoreEmpty(context) else { return }

        let records = holdingRecords()
        let holdingsByTicker = insert(records, into: context)
        insertCashFlows(into: context)
        insertSnapshots(into: context, valuation: Valuation(records: records))
        insertBenchmarks(into: context)
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
    /// 국내주식만 두 종목인 이유는 카테고리 카드의 행 구조 때문이다 — 한 카드에 행이 둘은
    /// 있어야 행 사이 구분선과 카드 안 정렬이 화면에서 보인다.
    ///
    /// 현재가를 `manualPrice` 로 고정하는 이유는 시세 폴백 순서 때문이다 — 시뮬레이터에서
    /// KIS·업비트 응답이 비면 평단가로 내려가서 손익이 전부 0 으로 보인다.
    private static func holdingRecords() -> [HoldingRecord] {
        [
            HoldingRecord(
                category: .cash,
                name: "수시입출금",
                quantity: 4_820_000,
                createdAt: monthsAgo(7),
                updatedAt: monthsAgo(7)
            ),
            HoldingRecord(
                category: .domesticStock,
                name: "삼성전자",
                ticker: Constants.samsungElectronicsTicker,
                quantity: 120,
                averagePrice: 71_500,
                manualPrice: 84_300,
                createdAt: monthsAgo(7),
                updatedAt: daysAgo(1)
            ),
            HoldingRecord(
                category: .domesticStock,
                name: "SK하이닉스",
                ticker: "000660",
                quantity: 15,
                averagePrice: 198_400,
                manualPrice: 217_000,
                createdAt: monthsAgo(7),
                updatedAt: daysAgo(1)
            ),
            HoldingRecord(
                category: .overseasStock,
                name: "Apple",
                ticker: Constants.appleTicker,
                currency: .usd,
                quantity: 18,
                averagePrice: 214.60,
                manualPrice: 246.20,
                createdAt: monthsAgo(6),
                updatedAt: daysAgo(1)
            ),
            HoldingRecord(
                category: .etf,
                name: "TIGER 미국S&P500",
                ticker: Constants.tigerUSLargeCapTicker,
                quantity: 310,
                averagePrice: 18_940,
                manualPrice: 21_650,
                createdAt: monthsAgo(6),
                updatedAt: daysAgo(1)
            ),
            HoldingRecord(
                category: .crypto,
                name: "비트코인",
                ticker: Constants.bitcoinTicker,
                quantity: 0.0412,
                averagePrice: 96_400_000,
                manualPrice: 88_200_000,
                createdAt: monthsAgo(5),
                updatedAt: daysAgo(1)
            ),
        ]
    }

    private static func insert(
        _ records: [HoldingRecord],
        into context: ModelContext
    ) -> [String: Holding] {
        var holdingsByTicker: [String: Holding] = [:]
        for record in records {
            let holding = Holding(record: record)
            context.insert(holding)
            holdingsByTicker[holding.ticker] = holding
        }
        return holdingsByTicker
    }

    /// 입출금이 있어야 YTD 수익률이 "순수 투자 성과"와 다른 값으로 갈라져 계산을 확인할 수 있다.
    ///
    /// 금액을 총자산의 2~3% 로 눌러 둔 이유는 추이 차트 때문이다. 수익률은 입출금을 빼고
    /// 계산하므로 입출금이 있는 날 선이 수직으로 끊긴다 — 정상 동작이지만 금액이 크면
    /// 렌더링이 깨진 것처럼 보이는 절벽이 된다.
    private static func insertCashFlows(into context: ModelContext) {
        let records = [
            CashFlowRecord(
                occurredOn: monthsAgo(6),
                amount: 800_000,
                kind: .deposit,
                memo: "정기 적립"
            ),
            CashFlowRecord(
                occurredOn: monthsAgo(3),
                amount: 500_000,
                kind: .withdrawal,
                memo: "비상금 인출"
            ),
        ]

        for record in records {
            context.insert(CashFlowEvent(record: record))
        }
    }

    /// 연초부터 어제까지 **하루도 빠짐없이** 넣는다.
    ///
    /// 월별 카드가 이번 달 일간 수익률을 일별 기록에서 만들고, 전일 대비 변동은 어제 기록을
    /// 찾아야 뜨며, YTD 는 올해 첫 기록을 기준값으로 잡는다 — 셋 다 같은 일별 시리즈를 본다.
    ///
    /// 종점을 오늘 보유 평가액에 맞추는 것이 이 함수의 핵심이다. 시리즈를 따로 지어내면
    /// YTD 가 `(기말 − 기초 − 입출금) / 기초` 에서 음수로 뒤집혀, 종목은 전부 수익인데
    /// 성과 탭만 손실로 표시되는 화면이 나온다.
    private static func insertSnapshots(into context: ModelContext, valuation: Valuation) {
        guard let series = dailySeries() else { return }

        for (date, progress) in series {
            let total = rounded(valuation.total * multiplier(at: progress))
            let record = NetWorthRecord(
                recordedOn: date,
                totalInKRW: .krw(total),
                totalInUSD: .usd(rounded(total / Constants.usdToKRWRate)),
                categorySubtotals: valuation.weights.map {
                    CategorySubtotal(category: $0.category, amount: rounded(total * $0.weight))
                }
            )
            context.insert(NetWorthSnapshot(record: record))
        }
    }

    /// 지수를 넣지 않으면 비교 시트의 네 줄이 전부 "불러오지 못했어요"로 잠겨서 액세서리의
    /// 비교 컨트롤·초과수익 문구를 아예 눌러볼 수 없다.
    ///
    /// 날짜는 순자산 스냅샷과 같은 일별 격자를 쓴다 — 비교는 같은 날짜끼리 맞물려야 한다.
    ///
    /// S&P 500 만 포트폴리오보다 더 오르게 두었다 — 초과수익이 음수인 경우까지 한 시드에서
    /// 확인해야 상승 빨강·하락 파랑이 스트립에도 제대로 적용됐는지 볼 수 있다.
    private static func insertBenchmarks(into context: ModelContext) {
        guard let series = dailySeries() else { return }

        for index in Constants.benchmarkShapes {
            for (date, progress) in series {
                let growth = 1 + (index.gain - 1) * Decimal(progress)
                let record = BenchmarkRecord(
                    recordedOn: date,
                    index: index.index,
                    value: rounded(index.start * growth * wobble(at: progress, phase: index.phase))
                )
                context.insert(BenchmarkSnapshot(record: record))
            }
        }
    }

    private static func insertJournalEntries(
        into context: ModelContext,
        taggedWith holdingsByTicker: [String: Holding]
    ) {
        let entries: [(ticker: String, daysAgo: Int, title: String, content: String)] = [
            (
                Constants.samsungElectronicsTicker, 3, "삼성전자 추가 매수",
                "실적 발표 이후 조정에서 20주 더 담았다. 평단이 내려가서 심리적으로 편해졌다."
            ),
            (
                Constants.tigerUSLargeCapTicker, 9, "적립식은 그대로 간다",
                "지수가 흔들려도 매달 같은 날 같은 금액. 타이밍을 재기 시작하면 규칙이 무너진다."
            ),
            (
                Constants.bitcoinTicker, 21, "비트코인 비중 점검",
                "전체의 10% 수준. 변동성 대비 감당 가능한 범위라 당분간 추가 매수는 보류한다."
            ),
            (
                "000660", 40, "SK하이닉스 비중 조절",
                "반도체 두 종목이 국내 비중의 대부분이라 쏠림이 있다. 다음 매수는 다른 곳으로."
            ),
            (
                Constants.appleTicker, 68, "환율 부담에도 AAPL 유지",
                "원달러가 높아 신규 진입은 미루되, 이미 산 물량은 환헤지 없이 그대로 간다."
            ),
            (
                Constants.samsungElectronicsTicker, 112, "올해 원칙 세 가지",
                "①현금 15% 아래로 내리지 않기 ②한 종목 30% 넘기지 않기 ③손실 났다고 물타지 않기."
            ),
        ]

        for entry in entries {
            let writtenAt = daysAgo(entry.daysAgo)
            let record = JournalRecord(
                writtenAt: writtenAt,
                title: entry.title,
                content: entry.content,
                updatedAt: writtenAt
            )
            let journalEntry = JournalEntry(record: record)
            context.insert(journalEntry)
            // `JournalEntry.init(record:)` 는 식별자만 받고 관계는 채우지 않는다.
            // Repository 와 마찬가지로 모델 인스턴스를 직접 물려야 종목 태그가 붙는다.
            journalEntry.holdings = holdingsByTicker[entry.ticker].map { [$0] }
        }
    }

    // MARK: - Function (시리즈 생성)

    /// 연초부터 어제까지의 (날짜, 진행률 0…1). 오늘은 넣지 않는다 — 오늘 값은 보유 종목을
    /// 실시간 평가해서 나오므로, 스냅샷으로도 넣으면 같은 날이 두 벌이 된다.
    private static func dailySeries() -> [(date: Date, progress: Double)]? {
        let today = calendar.startOfDay(for: Date())
        guard
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: today)),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: today),
            let span = calendar.dateComponents([.day], from: yearStart, to: lastDay).day,
            span > 0
        else { return nil }

        return (0...span).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: yearStart) else {
                return nil
            }
            return (date, Double(offset) / Double(span))
        }
    }

    /// 진행률에 대한 총자산 배수. 연초 `openingRatio` 에서 어제 `closingRatio` 까지 오른다.
    ///
    /// 곧게만 올리면 추이선이 자를 댄 것처럼 보여 두 개의 사인파로 조정 구간을 만든다.
    /// 파형에 `(1 − progress)` 를 곱해 양 끝에서는 0 이 되게 했다 — 시작·끝값이 정확해야
    /// YTD 기준값과 전일 대비 변동폭이 의도한 숫자로 떨어진다.
    private static func multiplier(at progress: Double) -> Decimal {
        let base = Constants.openingRatio
            + (Constants.closingRatio - Constants.openingRatio) * progress
        let swing = (1 - progress) * (
            Constants.majorSwing * sin(progress * Constants.majorFrequency)
                + Constants.minorSwing * sin(progress * Constants.minorFrequency)
        )
        return Decimal(base + swing)
    }

    /// 지수용 흔들림. 순자산 곡선과 위상을 어긋나게 해서 두 선이 겹쳐 보이지 않게 한다.
    private static func wobble(at progress: Double, phase: Double) -> Decimal {
        Decimal(1 + (1 - progress) * Constants.majorSwing * sin(progress * 9.4 + phase))
    }

    // MARK: - Function (도우미)

    /// 성과·추이 계산이 모두 `Calendar.current` 를 쓰므로 시드도 같은 달력의 자정에 맞춘다.
    private static var calendar: Calendar { .current }

    private static func daysAgo(_ count: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -count, to: today) ?? today
    }

    private static func monthsAgo(_ count: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .month, value: -count, to: today) ?? today
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .plain)
        return result
    }
}

/// 오늘 보유 종목을 평가했을 때 나오는 총액과 자산군별 비중.
///
/// 스냅샷 시리즈가 이 값을 종점으로 삼아야 순자산·포트폴리오·성과 세 탭이 같은 총액을 말한다.
private struct Valuation {
    // MARK: - Property

    let total: Decimal
    let weights: [(category: AssetCategory, weight: Decimal)]

    // MARK: - Function

    init(records: [HoldingRecord]) {
        let amounts = records.map { (category: $0.category, amount: Self.amount(of: $0)) }
        let total = amounts.reduce(Decimal.zero) { $0 + $1.amount }

        self.total = total
        weights = AssetCategory.allCases.compactMap { category in
            let subtotal = amounts.filter { $0.category == category }
                .reduce(Decimal.zero) { $0 + $1.amount }
            guard subtotal > 0, total > 0 else { return nil }
            return (category, subtotal / total)
        }
    }

    /// 평가액 계산은 앱과 같은 폴백 순서를 따른다 — 현재가 → 평단가.
    /// 현금은 단가가 없고 수량 자체가 금액이라 단가를 1 로 둔다.
    private static func amount(of record: HoldingRecord) -> Decimal {
        let unitPrice = record.manualPrice ?? record.averagePrice ?? 1
        let inKRW = record.currency == .usd ? unitPrice * Constants.usdToKRWRate : unitPrice
        return record.quantity * inKRW
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

    /// 연초 총자산 = 오늘 평가액 × 이 값. 순입출금(+30만)을 빼고도 YTD 가 +13% 언저리로
    /// 떨어지도록 잡았다 — 포트폴리오 탭의 평가손익(+11.6%)과 같은 방향이어야 한다.
    static let openingRatio: Double = 0.8773

    /// 어제 총자산 배수. 오늘 평가액과의 차이(1%)가 그대로 전일 대비 변동으로 표시된다.
    static let closingRatio: Double = 0.990

    static let majorSwing: Double = 0.024
    static let minorSwing: Double = 0.012
    static let majorFrequency: Double = 11.5
    static let minorFrequency: Double = 27.3

    /// 지수별 (시작값, 연초 대비 상승률, 위상). 순자산은 연초 대비 약 1.13 배 오르므로
    /// S&P 500 만 그보다 높게 두어 초과수익이 음수인 경우를 만든다.
    static let benchmarkShapes: [(index: BenchmarkIndex, start: Decimal, gain: Decimal, phase: Double)] = [
        (.kospi, 2_610, 1.098, 0.0),
        (.sp500, 5_910, 1.272, 1.7),
        (.nasdaq, 19_420, 1.113, 3.1),
        (.bitcoin, 92_400_000, 0.955, 4.6),
    ]
}
#endif
