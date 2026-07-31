import Foundation
import HannunCore

/// 업비트 `GET /v1/ticker` 응답 한 건 (§11.1).
struct UpbitTickerDTO: Decodable, Sendable, Equatable {
    /// 마켓 코드 (예: `KRW-BTC`)
    let market: String
    /// 현재가. KRW 마켓이므로 원화 표시가다.
    let tradePrice: Decimal
    /// 전일 대비 등락률 (부호 있음)
    let signedChangeRate: Double

    private enum CodingKeys: String, CodingKey {
        case market
        case tradePrice = "trade_price"
        case signedChangeRate = "signed_change_rate"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        market = try container.decode(String.self, forKey: .market)
        signedChangeRate = try container.decode(Double.self, forKey: .signedChangeRate)

        // JSON 숫자를 Decimal 로 바로 받으면 이진 부동소수 오차가 그대로 남아
        // 0.1234 가 0.12339999999999999 로 굳는다. Double 의 description 은
        // 원래 값으로 되돌아가는 최단 표기라, 이를 거치면 표시가가 그대로 보존된다.
        let rawPrice = try container.decode(Double.self, forKey: .tradePrice)
        tradePrice = Decimal(string: String(rawPrice)) ?? Decimal(rawPrice)
    }

    init(market: String, tradePrice: Decimal, signedChangeRate: Double) {
        self.market = market
        self.tradePrice = tradePrice
        self.signedChangeRate = signedChangeRate
    }
}

extension UpbitTickerDTO {
    /// 업비트 KRW 마켓은 원화 표시가만 제공한다.
    func toDomain() -> Money { .krw(tradePrice) }
}
