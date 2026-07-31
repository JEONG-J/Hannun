//
//  DIContainer.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Observation

/// Protocol → 구현체 해석기. 등록은 구현체를 아는 유일한 타깃인 앱이 시작 시 한 번만 수행한다.
///
/// `@Observable` 은 SwiftUI Environment 로 내려보내기 위한 조건일 뿐 관찰할 상태는 없다.
/// 저장소가 관찰 대상이면 View 갱신 도중의 resolve 가 다시 갱신을 부르므로 전부 제외한다.
@MainActor
@Observable
public final class DIContainer {
    // MARK: - Property

    @ObservationIgnored
    private var factories: [ObjectIdentifier: @MainActor () -> Any] = [:]

    @ObservationIgnored
    private var instances: [ObjectIdentifier: Any] = [:]

    // MARK: - Function

    public init() {}

    /// 같은 타입을 다시 등록하면 이전 팩토리와 해석해 둔 인스턴스를 모두 대체한다.
    public func register<Service>(
        _ type: Service.Type,
        factory: @escaping @MainActor () -> Service
    ) {
        let key = ObjectIdentifier(type)
        factories[key] = factory
        instances[key] = nil
    }

    /// 첫 해석 결과를 보관해 이후 호출은 같은 인스턴스를 돌려준다.
    /// 등록 누락은 앱 구성 실수이므로 런타임에 감추지 않고 즉시 멈춘다.
    public func resolve<Service>(_ type: Service.Type) -> Service {
        let key = ObjectIdentifier(type)
        if let instance = instances[key] as? Service { return instance }

        guard let factory = factories[key] else {
            preconditionFailure("DIContainer 에 \(type) 이 등록되지 않았습니다.")
        }
        guard let resolved = factory() as? Service else {
            preconditionFailure("DIContainer 의 \(type) 팩토리가 다른 타입을 돌려줬습니다.")
        }

        instances[key] = resolved
        return resolved
    }

    /// 보관 중인 인스턴스만 버린다. 등록은 남으므로 다음 resolve 에서 새로 만들어진다.
    public func resetCache() {
        instances.removeAll()
    }
}
