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
/// 심볼을 보고 제공자를 고르고, 앞단에 15분 캐시를 둔다.
/// 갱신에 실패하면 마지막 캐시값으로 버틴다.
public struct MarketDataRepository: MarketDataServiceProtocol {
    /// 심볼로 제공자를 판별한다. 업비트 마켓 코드는 항상 `KRW-` 로 시작한다.
    private enum Provider {
        case upbit
        case koreaInvestment

        init(symbol: String) {
            self = symbol.hasPrefix("KRW-") ? .upbit : .koreaInvestment
        }
    }

    private let upbit: UpbitClient
    private let cache: QuoteCache

    public init(session: URLSession = .shared) {
        self.init(upbit: UpbitClient(session: session), cache: QuoteCache())
    }

    init(upbit: UpbitClient, cache: QuoteCache) {
        self.upbit = upbit
        self.cache = cache
    }

    public func currentPrice(symbol: String) async throws -> Money {
        // TODO: KIS 클라이언트 연결 후 이 가드를 없앤다 (국내·해외 주식/ETF, 지수, 환율)
        guard case .upbit = Provider(symbol: symbol) else {
            throw AppError.validation("아직 시세를 조회할 수 없는 종목입니다: \(symbol)")
        }

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

        // 2. 제공자별로 묶어 배치 조회한다. 업비트는 한 번의 호출로 여러 마켓을 받는다.
        // TODO: .koreaInvestment 묶음은 KIS 클라이언트 연결 시 처리한다.
        let upbitMarkets = pending.filter { Provider(symbol: $0) == .upbit }
        guard !upbitMarkets.isEmpty else { return prices }

        do {
            let fetched = try await upbit.prices(markets: upbitMarkets)
            await cache.store(fetched)
            prices.merge(fetched) { _, fresh in fresh }
        } catch {
            // 갱신에 실패하면 마지막 캐시값으로 버틴다. 그마저 없으면 에러를 그대로 올린다.
            var stale: [String: Money] = [:]
            for market in upbitMarkets {
                if let value = await cache.staleValue(for: market) {
                    stale[market] = value
                }
            }
            guard !stale.isEmpty else { throw error }
            prices.merge(stale) { _, fallback in fallback }
        }

        return prices
    }
}
