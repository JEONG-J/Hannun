//
//  KISQuoteDTO.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 국내주식 현재가 시세 조회 응답의 `output`.
///
/// 확인 필요: 필드명은 KIS 국내주식 현재가 시세 응답 기준이다 — `stck_prpr`(주식 현재가),
/// `prdy_ctrt`(전일 대비율). 실키 검증 전이라 응답 원문과 대조가 필요하다.
struct KISDomesticQuoteDTO: Decodable, Sendable, Equatable {
    let currentPrice: Decimal
    let changeRate: Double?

    private enum CodingKeys: String, CodingKey {
        case currentPrice = "stck_prpr"
        case changeRate = "prdy_ctrt"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawPrice = try container.decode(String.self, forKey: .currentPrice)
        guard let price = Decimal(kisNumber: rawPrice) else {
            throw AppError.decoding("국내 종목 현재가가 비어 있습니다.")
        }
        currentPrice = price
        changeRate = try container.decodeIfPresent(String.self, forKey: .changeRate)
            .flatMap(Double.init)
    }
}

/// 해외주식 현재가 시세 조회 응답의 `output`.
///
/// 확인 필요: `last`(현재가), `rate`(등락률) 기준이다. 거래소 코드(`EXCD`)가 종목과 맞지 않으면
/// KIS 는 에러 대신 빈 문자열을 돌려주므로, 디코딩 실패가 곧 "그 거래소에 없는 종목"이다.
struct KISOverseasQuoteDTO: Decodable, Sendable, Equatable {
    let currentPrice: Decimal
    let changeRate: Double?

    private enum CodingKeys: String, CodingKey {
        case currentPrice = "last"
        case changeRate = "rate"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawPrice = try container.decode(String.self, forKey: .currentPrice)
        guard let price = Decimal(kisNumber: rawPrice) else {
            throw AppError.decoding("해외 종목 현재가가 비어 있습니다.")
        }
        currentPrice = price
        changeRate = try container.decodeIfPresent(String.self, forKey: .changeRate)
            .flatMap(Double.init)
    }
}

extension KISDomesticQuoteDTO {
    /// 국내 종목은 원화 표시가다.
    func toDomain() -> Money { .krw(currentPrice) }
}

extension KISOverseasQuoteDTO {
    /// 해외(미국) 종목은 달러 표시가다. 원화 환산은 환율을 아는 상위 계층이 맡는다.
    func toDomain() -> Money { .usd(currentPrice) }
}
