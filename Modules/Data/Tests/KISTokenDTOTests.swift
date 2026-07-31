//
//  KISTokenDTOTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import Testing
@testable import HannunData

@Suite("KISTokenDTO")
struct KISTokenDTOTests {
    private static let issuedAt = Date(timeIntervalSince1970: 1_785_000_000)

    private func decode(_ json: String) throws -> KISTokenDTO {
        try JSONDecoder().decode(KISTokenDTO.self, from: Data(json.utf8))
    }

    @Test("expires_in 이 있으면 발급 시각에 더해 만료를 정한다")
    func prefersExpiresIn() throws {
        let dto = try decode("""
        {"access_token":"abc","token_type":"Bearer","expires_in":86400}
        """)
        let token = dto.toDomain(issuedAt: Self.issuedAt)

        #expect(token.accessToken == "abc")
        #expect(token.expiresAt == Self.issuedAt.addingTimeInterval(86400))
    }

    @Test("expires_in 이 없으면 만료 시각 문자열을 한국 표준시로 읽는다")
    func fallsBackToExpiryText() throws {
        let dto = try decode("""
        {"access_token":"abc","access_token_token_expired":"2026-08-02 09:00:00"}
        """)
        let token = dto.toDomain(issuedAt: Self.issuedAt)

        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 2
        components.hour = 9
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))

        #expect(token.expiresAt == calendar.date(from: components))
    }

    @Test("만료 정보가 없으면 KIS 기본 유효기간 24시간으로 본다")
    func fallsBackToDefaultLifetime() throws {
        let dto = try decode(#"{"access_token":"abc"}"#)
        let token = dto.toDomain(issuedAt: Self.issuedAt)

        #expect(token.expiresAt == Self.issuedAt.addingTimeInterval(24 * 60 * 60))
    }

    @Test("만료 여유 시간 안에 든 토큰은 유효하지 않다")
    func treatsNearExpiryAsInvalid() {
        let token = KISToken(
            accessToken: "abc",
            expiresAt: Self.issuedAt.addingTimeInterval(30)
        )

        #expect(token.isValid(at: Self.issuedAt, margin: 0))
        #expect(!token.isValid(at: Self.issuedAt, margin: 60))
    }
}
