//
//  Project+Module.swift
//  ProjectDescriptionHelpers
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription

/// 공유 계층 모듈용 `Project` 헬퍼 — Core / DesignSystem / Domain / Data / TestSupport.
///
/// 모듈 하나가 프로젝트 하나이고, 그 안에 `.staticFramework` 타깃 하나가 들어간다.
/// `includesTests: true` 면 `Tests/**` 를 소스로 쓰는 `{name}Tests` 타깃이 같은 프로젝트에 붙는다.
///
/// 경로는 전부 **모듈 디렉터리 기준 상대 경로**다 (`Sources/**`, `Tests/**`, `Resources/**`).
/// 다른 모듈을 참조할 때만 `.project(target:path: .relativeToRoot(...))` 로 저장소 루트를 기준 삼는다.
///
/// - Parameters:
///   - name: 타깃 이름 (예: `"HannunCore"`)
///   - bundleIdSuffix: bundleId 접미사 (예: `"core"` → `com.jeong.hannun.core`)
///   - resources: 번들에 담을 리소스. 선언하면 Tuist 가 `Bundle.module` 접근자를 생성한다
///   - dependencies: 메인 타깃 의존성
///   - additionalSettings: 타깃 단위 추가 빌드 설정 (프로젝트 공통 설정 위에 덧붙는다)
///   - includesTests: 유닛 테스트 타깃 생성 여부
///   - testDependencies: 테스트 코드가 직접 `import` 하는 모듈. 메인 타깃은 자동 포함된다
public func moduleProject(
    name: String,
    bundleIdSuffix: String,
    resources: ResourceFileElements? = nil,
    dependencies: [TargetDependency] = [],
    additionalSettings: SettingsDictionary = [:],
    includesTests: Bool = false,
    testDependencies: [TargetDependency] = []
) -> Project {
    var targets: [Target] = [
        .target(
            name: name,
            destinations: hannunDestinations,
            product: .staticFramework,
            bundleId: "\(bundleIdPrefix).\(bundleIdSuffix)",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["Sources/**"],
            resources: resources,
            dependencies: dependencies,
            settings: additionalSettings.isEmpty ? nil : .settings(base: additionalSettings)
        ),
    ]

    if includesTests {
        targets.append(
            .unitTestsTarget(
                for: name,
                bundleIdSuffix: bundleIdSuffix,
                dependencies: testDependencies
            )
        )
    }

    return Project(
        name: name,
        organizationName: hannunOrganizationName,
        settings: hannunProjectSettings,
        targets: targets
    )
}

extension Target {
    /// Swift Testing 전용 타깃. `import Testing` 은 toolchain 내장이라 별도 의존성이 없다.
    ///
    /// `dependencies` 에는 테스트 코드가 직접 `import` 하는 모듈을 모두 적는다.
    /// 대상 모듈을 통해 전이적으로 링크되더라도 `make inspect` 가 암묵적 의존성으로 잡는다.
    static func unitTestsTarget(
        for moduleName: String,
        bundleIdSuffix: String,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: "\(moduleName)Tests",
            destinations: hannunDestinations,
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(bundleIdSuffix).tests",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["Tests/**"],
            dependencies: [.target(name: moduleName)] + dependencies
        )
    }
}
