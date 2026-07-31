import Foundation
import HannunCore

/// 시세 조회 창구. KIS·업비트 합성 구현(CompositeMarketDataService)은 HannunData 에 있고
/// Domain 은 Moya 를 전혀 모른다 (§3 봉인 규칙).
public protocol MarketDataServiceProtocol: Sendable {
    func currentPrice(symbol: String) async throws -> Money

    /// 여러 종목의 현재가를 한 번에 조회한다.
    /// 외부 API 가 배치 조회를 지원하므로(§11.1) 호출량 제한을 아끼려면 이쪽을 쓴다.
    /// 조회하지 못한 심볼은 결과에서 빠진다.
    func currentPrices(symbols: [String]) async throws -> [String: Money]
}
