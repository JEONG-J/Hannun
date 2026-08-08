//
//  KISExchangeRateDTO.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 원/달러 환율 조회 응답의 `output1`.
///
/// 해외지수 기간별 시세 응답의 현재가 필드 `ovrs_nmix_prpr` 기준이다. 환율을 지수처럼
/// 취급하는 API 라 필드명이 "해외지수 현재가"다. 실키 응답 원문과 대조했다.
struct KISExchangeRateDTO: Decodable, Sendable, Equatable {
    let krwPerUSD: Decimal

    private enum CodingKeys: String, CodingKey {
        case krwPerUSD = "ovrs_nmix_prpr"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawRate = try container.decode(String.self, forKey: .krwPerUSD)
        guard let rate = Decimal(kisNumber: rawRate), rate > 0 else {
            throw AppError.decoding("환율이 비어 있습니다.")
        }
        krwPerUSD = rate
    }
}

extension KISExchangeRateDTO {
    func toDomain() -> ExchangeRate { ExchangeRate(krwPerUSD: krwPerUSD) }
}
