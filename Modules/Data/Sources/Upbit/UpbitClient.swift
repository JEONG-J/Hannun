import Foundation
import HannunCore

/// 업비트 시세 조회 클라이언트 (§11.1).
///
/// 인증이 없어 보관할 상태가 없으므로 actor 가 아니라 `Sendable` 값 타입이다.
/// 격리가 필요한 지점(요청 시퀀스)은 `NetworkClient` 가, 캐시는 `QuoteCache` 가 맡는다.
struct UpbitClient: Sendable {
    private let client: NetworkClient

    init(session: URLSession = .shared) {
        client = NetworkClient(session: session)
    }

    /// 마켓 코드별 현재가. 업비트가 돌려주지 않은 마켓은 결과에서 빠진다.
    func prices(markets: [String]) async throws -> [String: Money] {
        guard !markets.isEmpty else { return [:] }

        let tickers = try await client.send(
            UpbitEndpoint.ticker(markets: markets),
            as: [UpbitTickerDTO].self
        )

        return Dictionary(
            tickers.map { ($0.market, $0.toDomain()) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    /// 단일 마켓 현재가.
    /// - Throws: 업비트에 상장되지 않은 마켓이면 `AppError.validation`.
    ///   설계 문서 PF-2 는 이 경우 현재가 수동 입력으로 폴백하도록 정한다.
    func price(market: String) async throws -> Money {
        guard let price = try await prices(markets: [market])[market] else {
            throw AppError.validation("업비트에서 조회할 수 없는 마켓입니다: \(market)")
        }
        return price
    }
}
