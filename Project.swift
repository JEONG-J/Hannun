import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "Hannun",
    organizationName: "Hannun",
    options: .options(defaultKnownRegions: ["ko", "en"], developmentRegion: "ko"),
    settings: .settings(
        base: .hannunBase,
        configurations: [
            .debug(name: .debug, xcconfig: "App/Config/Hannun.debug.xcconfig"),
            .release(name: .release, xcconfig: "App/Config/Hannun.release.xcconfig"),
        ]
    ),
    targets: [
        // MARK: - App
        .target(
            name: "Hannun",
            destinations: hannunDestinations,
            product: .app,
            bundleId: bundleIdPrefix,
            deploymentTargets: hannunDeploymentTargets,
            infoPlist: .file(path: "App/Resources/Info.plist"),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/Assets.xcassets"],
            entitlements: .file(path: "App/Config/Hannun.entitlements"),
            dependencies: [
                .target(name: "NetWorthFeature"),
                .target(name: "PortfolioFeature"),
                .target(name: "PerformanceFeature"),
                .target(name: "JournalFeature"),
                .target(name: "HannunData"),        // 구현체를 아는 유일한 지점
            ],
            settings: .settings(base: .hannunBase)
        ),

        // MARK: - Shared
        .module(name: "HannunCore", path: "Modules/Core", dependencies: []),
        .module(name: "HannunDesignSystem", path: "Modules/DesignSystem", hasResources: true,
                dependencies: [.target(name: "HannunCore")]),
        .module(name: "HannunDomain", path: "Modules/Domain",
                dependencies: [.target(name: "HannunCore")]),
        // 네트워크는 URLSession + actor 로 직접 구현한다. 외부 SPM 의존성은 없다 (§5.5).
        .module(name: "HannunData", path: "Modules/Data",
                dependencies: [
                    .target(name: "HannunDomain"),
                    .target(name: "HannunCore"),
                ]),
        .module(name: "HannunTestSupport", path: "Modules/TestSupport",
                dependencies: [
                    .target(name: "HannunDomain"),
                    .target(name: "HannunCore"),
                ]),

        // MARK: - Features
        .feature(name: "NetWorthFeature", path: "Features/NetWorth"),
        .feature(name: "PortfolioFeature", path: "Features/Portfolio"),
        .feature(name: "PerformanceFeature", path: "Features/Performance"),
        .feature(name: "JournalFeature", path: "Features/Journal"),

        // MARK: - Tests
        // extraDependencies 는 테스트 코드가 직접 import 하는 모듈이다.
        // 전이 링크로 심볼은 풀리지만 `make inspect` 가 암묵적 의존성으로 잡으므로 명시한다.
        .unitTests(for: "HannunCore", path: "Modules/Core"),
        .unitTests(for: "HannunDomain", path: "Modules/Domain",
                   extraDependencies: [.target(name: "HannunCore")]),
        .unitTests(for: "HannunData", path: "Modules/Data",
                   extraDependencies: [.target(name: "HannunCore")]),
        .unitTests(for: "PortfolioFeature", path: "Features/Portfolio"),
        .unitTests(for: "PerformanceFeature", path: "Features/Performance"),
    ],
    schemes: [
        .scheme(
            name: "Hannun",
            shared: true,
            buildAction: .buildAction(targets: ["Hannun"]),
            testAction: .targets([
                "HannunCoreTests", "HannunDomainTests", "HannunDataTests",
                "PortfolioFeatureTests", "PerformanceFeatureTests",
            ]),
            runAction: .runAction(configuration: .debug, executable: "Hannun")
        ),
    ]
)
