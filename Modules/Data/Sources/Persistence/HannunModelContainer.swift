//
//  HannunModelContainer.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import SwiftData

/// 앱이 쓰는 `ModelContainer` 를 만드는 유일한 지점.
///
/// 컨테이너 생성이 여기 한 곳뿐이라, iCloud 동기화를 켤 때 `cloudKitDatabase` 한 줄만 바꾸면 된다.
public enum HannunModelContainer {
    // MARK: - Function

    /// - Parameter inMemory: 테스트·프리뷰처럼 디스크에 남기면 안 되는 경우 `true`.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = HannunSchema.schema

        // TODO: 이슈 #9 에서 번들 ID 확정 후 `.private("iCloud.<bundleId>")` 로 교체.
        // 지금 컨테이너를 만들어두면 번들 ID 변경 시 쌓인 스키마·레코드를 버려야 한다.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            throw AppError.persistence("저장소를 열지 못했어요. \(error.localizedDescription)")
        }
    }
}
