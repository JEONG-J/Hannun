//
//  HannunSchema.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftData

/// 앱 전체가 하나의 `ModelContainer` 로 묶이므로 엔티티 목록도 한 곳에만 둔다.
///
/// 저장소 팩토리(`HannunData`)와 테스트용 인메모리 컨테이너(`HannunTestSupport`)가
/// 같은 목록을 봐야 스키마가 갈라지지 않는다.
public enum HannunSchema {
    /// 계산 프로퍼티인 이유는 메타타입 배열을 전역 상태로 두지 않기 위해서다.
    public static var models: [any PersistentModel.Type] {
        [
            Holding.self,
            CashFlowEvent.self,
            NetWorthSnapshot.self,
            BenchmarkSnapshot.self,
            JournalEntry.self,
        ]
    }

    public static var schema: Schema {
        Schema(models)
    }
}
