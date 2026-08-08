//
//  Project.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 앱 타깃 하나만 담는 루트 프로젝트.
///
/// 모듈은 각자 `Modules/*/Project.swift` · `Features/*/Project.swift` 에 있고,
/// `Workspace.swift` 가 glob 으로 묶는다. 여기에는 앱 셸(엔트리포인트·DI 등록·Info.plist·
/// entitlements·시크릿 xcconfig)만 둔다.
let project = Project(
    name: "Hannun",
    organizationName: hannunOrganizationName,
    options: .options(defaultKnownRegions: ["ko", "en"], developmentRegion: "ko"),
    settings: .settings(
        base: .hannunBase,
        configurations: [
            .debug(name: .debug, xcconfig: "App/Config/Hannun.debug.xcconfig"),
            .release(name: .release, xcconfig: "App/Config/Hannun.release.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "Hannun",
            destinations: hannunDestinations,
            product: .app,
            bundleId: bundleIdPrefix,
            deploymentTargets: hannunDeploymentTargets,
            infoPlist: .file(path: "App/Resources/Info.plist"),
            sources: ["App/Sources/**"],
            resources: [
                "App/Resources/Assets.xcassets",
                "App/Resources/AppIcon.icon",
                "App/Resources/PrivacyInfo.xcprivacy",
            ],
            entitlements: .file(path: "App/Config/Hannun.entitlements"),
            dependencies: [
                .project(target: "NetWorthFeature", path: .relativeToRoot("Features/NetWorth")),
                .project(target: "PortfolioFeature", path: .relativeToRoot("Features/Portfolio")),
                .project(
                    target: "PerformanceFeature",
                    path: .relativeToRoot("Features/Performance")
                ),
                .project(target: "JournalFeature", path: .relativeToRoot("Features/Journal")),
                // 구현체를 아는 유일한 지점
                .project(target: "HannunData", path: .relativeToRoot("Modules/Data")),
                // 등록할 Protocol 메타타입 참조
                .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
                // DIContainer·ErrorHandler 직접 사용
                .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
            ]
        ),
    ]
)
