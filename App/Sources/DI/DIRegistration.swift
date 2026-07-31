//
//  DIRegistration.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore
import HannunData

/// Protocol → 구현체 등록을 모으는 지점. 앱 타깃만이 HannunData 를 알기 때문에
/// 이 파일이 구현체를 아는 유일한 곳이다.
///
/// TODO: Repository·UseCase 구현체를 container.register(...) 로 채운다 (M2).
enum DIRegistration {
    @MainActor
    static func registerAll(into container: DIContainer) {}
}
