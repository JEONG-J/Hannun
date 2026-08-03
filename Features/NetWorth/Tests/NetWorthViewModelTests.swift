//
//  NetWorthViewModelTests.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import HannunTestSupport
import Testing

@testable import NetWorthFeature

@Suite("순자산 ViewModel")
struct NetWorthViewModelTests {

    // MARK: - NW-1 총자산

    @Test("모든 보유의 평가금액을 합쳐 총자산을 만든다")
    @MainActor
    func sumsMarketValueOfEveryHolding() async {
        let viewModel = makeViewModel(holdings: SampleFixtures.mixedHoldings)

        await viewModel.load()

        #expect(viewModel.summary.value?.total == .krw(9_500_000))
    }

    @Test("시세 조회에 실패해도 수동 입력가로 평가한다")
    @MainActor
    func fallsBackToManualPriceWhenQuotesFail() async {
        let viewModel = makeViewModel(
            holdings: [
                SampleRecords.holding(
                    category: .domesticStock,
                    name: "삼성전자",
                    ticker: "005930",
                    quantity: 10,
                    averagePrice: 60_000,
                    manualPrice: 70_000
                ),
            ],
            marketData: FixedPriceMarketDataService(failure: .network("끊김"))
        )

        await viewModel.load()

        #expect(viewModel.summary.value?.total == .krw(700_000))
    }

    @Test("갱신에 실패하면 마지막 값을 유지하고 stale 로 표시한다")
    @MainActor
    func keepsLastValueAndMarksStaleOnRefreshFailure() async {
        let netWorth = ToggleableNetWorthUseCase(total: .krw(1_000_000))
        let viewModel = makeViewModel(fetchNetWorth: netWorth)

        await viewModel.load()
        netWorth.failure = .network("끊김")
        await viewModel.load()

        #expect(viewModel.summary.value?.total == .krw(1_000_000))
        #expect(viewModel.freshness == .stale(since: SampleFixtures.refreshedAt))
    }

    @Test("한 번도 성공하지 못한 채 실패하면 인라인 실패 상태다")
    @MainActor
    func failsInlineWhenNothingLoadedYet() async {
        let netWorth = ToggleableNetWorthUseCase(total: .krw(1_000_000))
        netWorth.failure = .network("끊김")
        let viewModel = makeViewModel(fetchNetWorth: netWorth)

        await viewModel.load()

        #expect(viewModel.summary.error == .network("끊김"))
        #expect(viewModel.freshness == .unknown)
    }

    @Test("모든 시세가 최신이면 갱신 시각을 그대로 쓴다")
    @MainActor
    func reportsFreshWhenEveryQuoteIsCurrent() async {
        let viewModel = makeViewModel(holdings: SampleFixtures.mixedHoldings)

        await viewModel.load()

        #expect(viewModel.freshness == .fresh(SampleFixtures.refreshedAt))
    }

    @Test("일부 종목만 낡은 시세여도 낡은 쪽 시각으로 stale 을 표시한다")
    @MainActor
    func marksStaleWhenAnyQuoteIsStale() async {
        let viewModel = makeViewModel(
            holdings: SampleFixtures.mixedHoldings,
            marketData: FixedPriceMarketDataService(
                prices: SampleFixtures.prices,
                staleSymbols: ["005930"],
                asOf: SampleFixtures.quotedAt
            )
        )

        await viewModel.load()

        #expect(viewModel.summary.value?.total == .krw(9_500_000))
        #expect(viewModel.freshness == .stale(since: SampleFixtures.quotedAt))
    }

    @Test("시세를 한 번도 받지 못한 종목이 있으면 기준 시각 없이 stale 이다")
    @MainActor
    func marksStaleWithoutDateWhenQuoteNeverArrived() async {
        let viewModel = makeViewModel(
            holdings: SampleFixtures.mixedHoldings,
            marketData: FixedPriceMarketDataService(asOf: SampleFixtures.quotedAt)
        )

        await viewModel.load()

        #expect(viewModel.freshness == .stale(since: nil))
    }

    @Test("기준 시각 없이 stale 이어도 값을 채운 시각은 남는다")
    @MainActor
    func keepsRefreshTimeWithoutQuoteBasis() async {
        let viewModel = makeViewModel(
            holdings: SampleFixtures.mixedHoldings,
            marketData: FixedPriceMarketDataService(asOf: SampleFixtures.quotedAt)
        )

        await viewModel.load()

        #expect(viewModel.lastRefreshedAt == SampleFixtures.refreshedAt)
    }

    @Test("한 번도 채우지 못했으면 시각이 없다")
    @MainActor
    func hasNoRefreshTimeBeforeFirstSuccess() async {
        let netWorth = ToggleableNetWorthUseCase(total: .krw(1_000_000))
        netWorth.failure = .network("끊김")
        let viewModel = makeViewModel(fetchNetWorth: netWorth)

        await viewModel.load()

        #expect(viewModel.lastRefreshedAt == nil)
    }

    // MARK: - NW-2 기준 통화

    @Test("기준 통화를 바꾸면 다시 불러오기 전에 즉시 재환산한다")
    @MainActor
    func reconvertsImmediatelyOnCurrencyChange() async {
        let viewModel = makeViewModel(
            fetchNetWorth: ToggleableNetWorthUseCase(total: .krw(1_300_000))
        )

        await viewModel.load()
        viewModel.baseCurrency = .usd

        #expect(viewModel.baseCurrency == .usd)
        #expect(viewModel.summary.value?.total == .usd(1_000))
    }

    @Test("같은 통화를 다시 고르면 아무것도 바뀌지 않는다")
    @MainActor
    func ignoresRedundantCurrencyChange() async {
        let viewModel = makeViewModel(
            fetchNetWorth: ToggleableNetWorthUseCase(total: .krw(1_300_000))
        )

        await viewModel.load()
        viewModel.baseCurrency = .krw

        #expect(viewModel.summary.value?.total == .krw(1_300_000))
    }

    // MARK: - NW-3 자산군별 비중

    @Test("자산군별 금액과 비중을 채운다")
    @MainActor
    func fillsCategoryWeights() async {
        let viewModel = makeViewModel(holdings: SampleFixtures.mixedHoldings)

        let expected: [AssetCategory: Decimal] = [
            .cash: 5_000_000,
            .domesticStock: 3_000_000,
            .crypto: 1_500_000,
        ]

        await viewModel.load()
        let breakdown = viewModel.summary.value?.fundedBreakdown ?? []

        #expect(breakdown.count == expected.count)
        for item in breakdown {
            #expect(item.amount.amount == expected[item.category])
        }

        // 나눗셈 잔여가 남으므로 합이 정확히 1 이 되지는 않는다.
        let weightSum = breakdown.reduce(Decimal.zero) { $0 + $1.weight }
        #expect(abs(weightSum - 1) < SampleFixtures.weightTolerance)
    }

    @Test("금액이 0 인 자산군은 도넛과 리스트에서 빠진다")
    @MainActor
    func dropsCategoriesWithoutAmount() async {
        let viewModel = makeViewModel(holdings: SampleFixtures.mixedHoldings)

        await viewModel.load()
        let categories = viewModel.summary.value?.fundedBreakdown.map(\.category) ?? []

        #expect(!categories.contains(.overseasStock))
        #expect(!categories.contains(.etf))
    }

    @Test("보유가 없으면 빈 상태다")
    @MainActor
    func reportsEmptyWithoutHoldings() async {
        let viewModel = makeViewModel(holdings: [])

        await viewModel.load()

        #expect(viewModel.summary.value?.isEmpty == true)
        #expect(viewModel.summary.value?.fundedBreakdown.isEmpty == true)
    }

    // MARK: - 전일 대비 변동

    @Test("직전 스냅샷이 있으면 전일 대비 변동을 계산한다")
    @MainActor
    func computesDailyChangeAgainstPreviousSnapshot() async {
        let viewModel = makeViewModel(
            fetchNetWorth: ToggleableNetWorthUseCase(total: .krw(1_100_000)),
            fetchTrend: StubTrendUseCase(
                points: [
                    NetWorthTrendPoint(
                        date: SampleRecords.day(2026, 7, 31),
                        total: .krw(1_000_000)
                    ),
                ]
            )
        )

        await viewModel.load()

        #expect(viewModel.summary.value?.dailyChange?.amount == .krw(100_000))
        #expect(viewModel.summary.value?.dailyChange?.ratio == 0.1)
    }

    @Test("비교할 스냅샷이 없으면 변동을 만들지 않는다")
    @MainActor
    func omitsDailyChangeWithoutPreviousSnapshot() async {
        let viewModel = makeViewModel(fetchTrend: StubTrendUseCase(points: []))

        await viewModel.load()

        #expect(viewModel.summary.value?.dailyChange == nil)
    }
}

// MARK: - Fixture

private enum SampleFixtures {
    /// 시세 조회 시각을 고정해 `freshness` 비교를 결정적으로 만든다.
    static let refreshedAt = SampleRecords.day(2026, 8, 1)

    /// 시세를 받아온 시각. 낡은 시세 배지가 가리키는 기준 시각이기도 하다.
    static let quotedAt = SampleRecords.day(2026, 7, 31)

    static let exchangeRateService = FixedExchangeRateService(krwPerUSD: 1_300)

    static let weightTolerance = Decimal(string: "0.0001") ?? .zero

    static let mixedHoldings: [HoldingRecord] = [
        SampleRecords.holding(category: .cash, name: "현금", quantity: 5_000_000),
        SampleRecords.holding(
            category: .domesticStock,
            name: "삼성전자",
            ticker: "005930",
            quantity: 30,
            averagePrice: 60_000
        ),
        SampleRecords.holding(
            category: .crypto,
            name: "비트코인",
            ticker: "BTC",
            quantity: 0.01,
            averagePrice: 100_000_000
        ),
    ]

    static let prices: [String: Money] = [
        "005930": .krw(100_000),
        "BTC": .krw(150_000_000),
    ]
}

@MainActor
private func makeViewModel(
    holdings: [HoldingRecord] = [],
    marketData: FixedPriceMarketDataService = FixedPriceMarketDataService(
        prices: SampleFixtures.prices,
        asOf: SampleFixtures.quotedAt
    ),
    fetchNetWorth: (any FetchNetWorthUseCaseProtocol)? = nil,
    fetchTrend: any FetchNetWorthTrendUseCaseProtocol = StubTrendUseCase(points: [])
) -> NetWorthViewModel {
    let repository = InMemoryHoldingRepository(holdings)
    let fetchHoldings = FetchHoldingsUseCase(
        holdingRepository: repository,
        marketDataService: marketData
    )
    let netWorth = fetchNetWorth
        ?? FetchNetWorthUseCase(fetchHoldingsUseCase: fetchHoldings)

    return NetWorthViewModel(
        fetchNetWorth: netWorth,
        fetchCategoryBreakdown: FetchCategoryBreakdownUseCase(fetchNetWorthUseCase: netWorth),
        fetchTrend: fetchTrend,
        exchangeRateService: SampleFixtures.exchangeRateService,
        calendar: SampleRecords.utcCalendar,
        now: { SampleFixtures.refreshedAt }
    )
}

// MARK: - Test Double

/// 실패를 도중에 켤 수 있는 대역. 저장소 대역만으로는 시세 실패가
/// `FetchHoldingsUseCase` 안에서 흡수돼 재현되지 않는다.
private final class ToggleableNetWorthUseCase: FetchNetWorthUseCaseProtocol, @unchecked Sendable {
    var failure: AppError?

    private let total: Money

    init(total: Money) {
        self.total = total
    }

    func execute(baseCurrency: Currency, exchangeRate: ExchangeRate) async throws -> NetWorth {
        if let failure { throw failure }

        return NetWorth(
            total: exchangeRate.convert(total, to: baseCurrency),
            valuations: []
        )
    }
}

private struct StubTrendUseCase: FetchNetWorthTrendUseCaseProtocol {
    let points: [NetWorthTrendPoint]

    func execute(
        from startDate: Date,
        to endDate: Date,
        granularity: TrendGranularity,
        baseCurrency: Currency
    ) async throws -> [NetWorthTrendPoint] {
        points
    }
}
