//
//  Project+Feature.swift
//  ProjectDescriptionHelpers
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription

/// Feature 모듈용 `Project` 헬퍼 — 탭 하나가 프로젝트 하나다.
///
/// Hannun 의 Feature 는 **Presentation 만 분할**한다. Domain/Data 는 `Modules/` 에서 공유하는데,
/// SwiftData 스키마가 단일 `ModelContainer` 로 묶이고 네 탭이 같은 엔티티를 교차 참조하기
/// 때문이다 — 근거는 `docs/design/2026-07-30-tuist-module-target-spec.md`.
///
/// 그래서 의존성이 Domain / DesignSystem / Core 세 개로 고정이고, 이 헬퍼를 거치는 한
/// `HannunData`(구현체)나 다른 Feature 로 가는 금지 간선이 애초에 생기지 않는다.
///
/// - Parameters:
///   - name: 타깃 이름 (예: `"PortfolioFeature"`)
///   - bundleIdSuffix: bundleId 접미사 (예: `"portfolio"` → `com.jeong.hannun.feature.portfolio`)
///   - extraDependencies: 고정 3종 외에 추가할 의존성 (SDK 등)
///   - includesTests: 유닛 테스트 타깃 생성 여부
///   - testDependencies: 테스트 코드가 직접 `import` 하는 모듈. 메인 타깃은 자동 포함된다
public func featureProject(
    name: String,
    bundleIdSuffix: String,
    extraDependencies: [TargetDependency] = [],
    includesTests: Bool = false,
    testDependencies: [TargetDependency] = []
) -> Project {
    let featureBundleIdSuffix = "feature.\(bundleIdSuffix)"

    var targets: [Target] = [
        .target(
            name: name,
            destinations: hannunDestinations,
            product: .staticFramework,
            bundleId: "\(bundleIdPrefix).\(featureBundleIdSuffix)",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
                .project(
                    target: "HannunDesignSystem",
                    path: .relativeToRoot("Modules/DesignSystem")
                ),
                .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
            ] + extraDependencies
        ),
    ]

    if includesTests {
        targets.append(
            .unitTestsTarget(
                for: name,
                bundleIdSuffix: featureBundleIdSuffix,
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
