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
    // MARK: - Property

    /// Developer 포털에 등록된 CloudKit 컨테이너. `Hannun.entitlements` 의 값과 같아야 한다.
    private static let cloudKitContainerID = "iCloud.com.hannun.app"

    // MARK: - Function

    /// - Parameter inMemory: 테스트·프리뷰처럼 디스크에 남기면 안 되는 경우 `true`.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = HannunSchema.schema

        // CloudKit 은 디스크 저장소를 요구하고, 테스트 번들에는 iCloud entitlement 가 없다.
        // 그래서 인메모리일 때는 동기화를 끈다.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(cloudKitContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            throw AppError.persistence("저장소를 열지 못했어요. \(error.localizedDescription)")
        }
    }
}
