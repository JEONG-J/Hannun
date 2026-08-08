//
//  KISRequestPacer.swift
//  HannunData
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation

/// KIS 요청이 서로 밟지 않도록 **시작 시각을 벌리는** 순번표.
///
/// KIS 는 유량을 넘기면 HTTP 200 에 `rt_cd=1` / `EGW00201 초당 거래건수를 초과하였습니다` 로
/// 답한다. 실전투자 개인 계정을 실키로 재보니 문서상 한도(초당 20건)보다 훨씬 빡빡했다 —
/// 0.05초 간격 10회는 4회, 0.25초 간격은 2회가 막혔고 **0.5초 간격에서 처음으로 전부 통과**했다.
///
/// 동시 요청 수만 조여서는 못 막는다. 창 하나를 다 보내면 곧바로 다음 창이 나가 결국 몰리고,
/// 시세와 환율은 서로 다른 저장소에서 동시에 출발하기 때문이다. 그래서 창이 아니라 시각을 잡는다.
///
/// 자리 예약과 대기를 나눠, 기다리는 동안에는 actor 를 붙잡지 않는다.
/// 호출자 여럿이 동시에 들어와도 각자 다른 순번을 받아 겹치지 않게 흩어진다.
actor KISRequestPacer {
    // MARK: - Property

    private let interval: TimeInterval
    private var nextSlot: Date = .distantPast

    // MARK: - Function

    init(interval: TimeInterval) {
        self.interval = max(0, interval)
    }

    /// 자기 순번이 될 때까지 기다린다.
    func waitForTurn() async {
        let now = Date()
        let slot = max(now, nextSlot)
        nextSlot = slot.addingTimeInterval(interval)

        let delay = slot.timeIntervalSince(now)
        guard delay > 0 else { return }
        try? await Task.sleep(for: .seconds(delay))
    }
}
