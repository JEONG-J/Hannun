import ProjectDescription

public extension Target {
    /// 공유 계층 모듈 (Core / DesignSystem / Domain / Data / TestSupport)
    static func module(
        name: String,
        path: String,
        hasResources: Bool = false,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: name,
            destinations: hannunDestinations,
            product: .staticFramework,
            bundleId: "\(bundleIdPrefix).\(name.lowercased())",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["\(path)/Sources/**"],
            resources: hasResources ? ["\(path)/Resources/**"] : nil,
            dependencies: dependencies,
            settings: .settings(base: .hannunBase)
        )
    }

    /// Feature 모듈 — 의존성이 항상 동일하므로 팩토리로 고정한다
    static func feature(name: String, path: String) -> Target {
        .module(
            name: name,
            path: path,
            dependencies: [
                .target(name: "HannunDomain"),
                .target(name: "HannunDesignSystem"),
                .target(name: "HannunCore"),
            ]
        )
    }

    /// Swift Testing 전용 타깃. `import Testing` 은 toolchain 내장이라 별도 의존성이 없다 (§6.2)
    ///
    /// `extraDependencies` 는 테스트 코드가 직접 `import` 하는 모듈을 명시하는 자리다.
    /// 대상 모듈을 통해 전이적으로 링크되더라도 `tuist inspect dependencies --only implicit`
    /// 이 암묵적 의존성으로 잡으므로, import 하는 모듈은 모두 여기에 선언한다.
    static func unitTests(
        for moduleName: String,
        path: String,
        extraDependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: "\(moduleName)Tests",
            destinations: hannunDestinations,
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(moduleName.lowercased()).tests",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["\(path)/Tests/**"],
            dependencies: [
                .target(name: moduleName),
                .target(name: "HannunTestSupport"),
            ] + extraDependencies,
            settings: .settings(base: .hannunBase)
        )
    }
}
