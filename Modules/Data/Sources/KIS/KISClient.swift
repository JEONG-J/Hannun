//
//  KISClient.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 한국투자증권 시세 조회 클라이언트.
///
/// 보관할 가변 상태가 없어 actor 가 아니다 — 토큰은 `KISTokenProvider` 가, 요청 시퀀스는
/// `NetworkClient` 가, 캐시는 `QuoteCache` 가 각자 들고 있다.
struct KISClient: Sendable {
    /// 배치 조회 한 건의 결과. 실패를 값으로 들고 있어야 부분 실패를 걸러낼 수 있다.
    private struct QuoteOutcome: Sendable {
        let symbol: String
        let result: Result<Money, AppError>
    }

    // MARK: - Property

    private let client: NetworkClient
    private let pacer: KISRequestPacer

    /// 환율 조회 하한. 연휴가 길어도 직전 고시가 구간 안에 들어오도록 일주일을 잡는다.
    private static let exchangeRateLookback: TimeInterval = 60 * 60 * 24 * 7

    /// 실키로 재서 실패가 사라진 최소 간격. 근거는 `KISRequestPacer` 주석에 있다.
    static let defaultRequestInterval: TimeInterval = 0.5

    // MARK: - Function

    /// - Parameter requestInterval: KIS 유량 제한에 걸리지 않도록 요청 사이에 두는 최소 간격.
    ///   테스트에서만 줄인다.
    init(
        session: URLSession = .shared,
        authorizer: any RequestAuthorizing,
        requestInterval: TimeInterval = KISClient.defaultRequestInterval
    ) {
        client = NetworkClient(session: session, authorizer: authorizer)
        pacer = KISRequestPacer(interval: requestInterval)
    }

    /// Info.plist 에 앱키가 없으면 nil 을 돌려준다.
    /// 키가 없어도 코인 시세와 수동 입력 폴백은 살아 있어야 하므로 실패가 아니라 미설정이다.
    static func makeIfConfigured(session: URLSession = .shared) -> KISClient? {
        guard let credentials = KISCredentials.fromInfoPlist() else { return nil }

        return KISClient(
            session: session,
            authorizer: KISTokenProvider(credentials: credentials, session: session)
        )
    }

    func price(for target: KISQuoteTarget) async throws -> Money {
        await pacer.waitForTurn()

        switch target {
        case let .domesticEquity(code):
            let response = try await client.send(
                KISEndpoint.domesticQuote(code: code),
                as: KISResponseEnvelope<KISDomesticQuoteDTO>.self
            )
            return try response.requireOutput().toDomain()

        case let .overseasEquity(exchange, ticker):
            let response = try await client.send(
                KISEndpoint.overseasQuote(exchange: exchange, ticker: ticker),
                as: KISResponseEnvelope<KISOverseasQuoteDTO>.self
            )
            return try response.requireOutput().toDomain()
        }
    }

    /// 여러 종목의 현재가를 한 번에 조회한다. 결과 키는 인자로 준 심볼 그대로다.
    ///
    /// KIS 현재가 API 는 단건이라 요청을 나눠 보낸다. **조회에 실패한 심볼은 결과에서 빠지고,
    /// 전부 실패했을 때만 첫 에러를 올린다** — 한 종목의 상장폐지가 나머지 시세를 막으면 안 된다.
    ///
    /// 전부 한꺼번에 띄워도 `KISRequestPacer` 가 출발 시각을 벌려 유량 제한에 걸리지 않는다.
    func prices(for targets: [String: KISQuoteTarget]) async throws -> [String: Money] {
        guard !targets.isEmpty else { return [:] }

        let outcomes = await withTaskGroup(of: QuoteOutcome.self) { group in
            for (symbol, target) in targets {
                group.addTask { [self] in
                    await outcome(symbol: symbol, target: target)
                }
            }

            var collected: [QuoteOutcome] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        var prices: [String: Money] = [:]
        var firstFailure: AppError?

        for outcome in outcomes {
            switch outcome.result {
            case let .success(money):
                prices[outcome.symbol] = money
            case let .failure(error):
                firstFailure = firstFailure ?? error
            }
        }

        if prices.isEmpty, let firstFailure {
            throw firstFailure
        }
        return prices
    }

    /// 원/달러 환율을 조회한다.
    ///
    /// - Parameter asOf: 조회 기준일. 기간별 시세 API 라 하한을 함께 보내야 하는데, 주말·연휴에는
    ///   당일 고시가 없어 며칠을 거슬러 잡는다.
    func exchangeRate(asOf date: Date = Date()) async throws -> ExchangeRate {
        await pacer.waitForTurn()

        let response = try await client.send(
            KISEndpoint.exchangeRate(
                from: date.addingTimeInterval(-Self.exchangeRateLookback),
                to: date
            ),
            as: KISResponseEnvelope<KISExchangeRateDTO>.self
        )
        return try response.requireOutput().toDomain()
    }

    private func outcome(symbol: String, target: KISQuoteTarget) async -> QuoteOutcome {
        do {
            return QuoteOutcome(symbol: symbol, result: .success(try await price(for: target)))
        } catch let error as AppError {
            return QuoteOutcome(symbol: symbol, result: .failure(error))
        } catch {
            return QuoteOutcome(symbol: symbol, result: .failure(AppError(transport: error)))
        }
    }
}
