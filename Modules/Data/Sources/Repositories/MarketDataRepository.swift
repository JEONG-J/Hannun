//
//  MarketDataRepository.swift
//  HannunData
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore
import HannunDomain

/// `MarketDataServiceProtocol` 의 실제 구현.
///
/// 심볼을 보고 제공자(업비트 / KIS)를 고르고, 앞단에 15분 캐시를 둔다.
/// 갱신에 실패하면 마지막 캐시값으로 버틴다.
public struct MarketDataRepository: MarketDataServiceProtocol {
    // MARK: - Property

    private let upbit: UpbitClient

    /// KIS 앱키가 없으면 nil 이다. 키 없이도 코인 시세는 그대로 동작해야 한다.
    private let koreaInvestment: KISClient?

    private let cache: QuoteCache

    // MARK: - Function

    public init(session: URLSession = .shared) {
        self.init(
            upbit: UpbitClient(session: session),
            koreaInvestment: KISClient.makeIfConfigured(session: session),
            cache: QuoteCache()
        )
    }

    init(upbit: UpbitClient, koreaInvestment: KISClient?, cache: QuoteCache) {
        self.upbit = upbit
        self.koreaInvestment = koreaInvestment
        self.cache = cache
    }

    public func currentPrice(symbol: String) async throws -> Money {
        guard let price = try await currentPrices(symbols: [symbol])[symbol] else {
            throw AppError.validation("현재가를 찾을 수 없는 종목입니다: \(symbol)")
        }
        return price
    }

    public func currentPrices(symbols: [String]) async throws -> [String: Money] {
        guard !symbols.isEmpty else { return [:] }

        // 1. 유효한 캐시부터 걷어내고, 남은 것만 네트워크로 간다.
        var prices: [String: Money] = [:]
        var pending: [String] = []

        for symbol in symbols {
            if let cached = await cache.value(for: symbol) {
                prices[symbol] = cached
            } else {
                pending.append(symbol)
            }
        }
        guard !pending.isEmpty else { return prices }

        // 2. 제공자별로 묶어 조회한다. 한쪽이 실패해도 다른 쪽 결과는 그대로 살린다.
        var upbitMarkets: [String] = []
        var koreaInvestmentTargets: [String: KISQuoteTarget] = [:]

        for symbol in pending {
            switch MarketSymbol(symbol) {
            case let .upbit(market):
                upbitMarkets.append(market)
            case let .koreaInvestment(target):
                koreaInvestmentTargets[symbol] = target
            }
        }

        var failures: [AppError] = []
        await fetchUpbit(markets: upbitMarkets, into: &prices, failures: &failures)
        await fetchKoreaInvestment(
            targets: koreaInvestmentTargets,
            into: &prices,
            failures: &failures
        )

        // 3. 아직 못 채운 심볼은 만료된 캐시로 버틴다 (명세 §8 갱신 실패 배지의 근거 데이터).
        for symbol in pending where prices[symbol] == nil {
            if let stale = await cache.staleValue(for: symbol) {
                prices[symbol] = stale
            }
        }

        // 하나도 못 채웠으면 원인을 감추지 않고 그대로 올린다.
        if prices.isEmpty, let failure = failures.first {
            throw failure
        }
        return prices
    }

    private func fetchUpbit(
        markets: [String],
        into prices: inout [String: Money],
        failures: inout [AppError]
    ) async {
        guard !markets.isEmpty else { return }

        do {
            let fetched = try await upbit.prices(markets: markets)
            await cache.store(fetched)
            prices.merge(fetched) { _, fresh in fresh }
        } catch {
            failures.append(error as? AppError ?? AppError(transport: error))
        }
    }

    private func fetchKoreaInvestment(
        targets: [String: KISQuoteTarget],
        into prices: inout [String: Money],
        failures: inout [AppError]
    ) async {
        guard !targets.isEmpty else { return }

        guard let koreaInvestment else {
            failures.append(
                .validation("주식·ETF 시세를 보려면 KIS 앱키를 설정해 주세요.")
            )
            return
        }

        do {
            let fetched = try await koreaInvestment.prices(for: targets)
            await cache.store(fetched)
            prices.merge(fetched) { _, fresh in fresh }
        } catch {
            failures.append(error as? AppError ?? AppError(transport: error))
        }
    }
}
