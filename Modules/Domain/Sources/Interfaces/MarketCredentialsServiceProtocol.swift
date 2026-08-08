//
//  MarketCredentialsServiceProtocol.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/8/26.
//

/// 시세 API 자격증명 창구. 실제 구현(`MarketCredentialsRepository`)은 HannunData 에 있다.
///
/// 앱은 시세 앱키를 바이너리에 담지 않고 **사용자가 자기 것을 넣어 쓴다.** 유량 제한도 발급
/// 제한도 계좌 단위라, 키 하나를 배포본이 나눠 쓰면 사용자가 늘수록 서로를 막기 때문이다.
/// 이 프로토콜에 KIS 라는 이름이 없는 것은 봉인 규칙 때문이다 — 어느 증권사를 쓰는지는 Data 의
/// 사정이고, 화면은 "시세 앱키" 하나만 안다.
public protocol MarketCredentialsServiceProtocol: Sendable {
    /// 쓸 수 있는 앱키가 저장돼 있는지.
    func isConfigured() async -> Bool

    /// 앱키를 검증한 뒤 저장한다.
    ///
    /// 저장만 하고 끝내지 않는 이유는 이 값이 **붙여넣기로 들어오는 36자 난수**이기 때문이다.
    /// 한 글자만 어긋나도 화면에서는 "시세 갱신 실패" 로만 보여 원인을 짚을 수 없다.
    /// - Throws: 키가 틀렸거나 검증 요청이 실패하면 던진다. 이때 이전 값은 그대로 남는다.
    func save(appKey: String, appSecret: String) async throws

    /// 저장된 앱키와 그 키로 받아 둔 토큰을 함께 지운다.
    func remove() async
}
