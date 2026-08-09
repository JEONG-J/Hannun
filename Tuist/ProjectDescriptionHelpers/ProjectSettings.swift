//
//  ProjectSettings.swift
//  ProjectDescriptionHelpers
//
//  Created by euijjang97 on 7/31/26.
//

import ProjectDescription

public let bundleIdPrefix = "com.hannun.app"
public let hannunOrganizationName = "Hannun"
public let hannunDestinations: Destinations = [.iPhone]
public let hannunDeploymentTargets: DeploymentTargets = .iOS("26.4")

public extension SettingsDictionary {
    static var hannunBase: SettingsDictionary {
        [
            "DEVELOPMENT_TEAM": "8B8B4462NV",
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY": "YES",
            "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
        ]
    }
}

/// 모든 프로젝트가 공유하는 프로젝트 단위 설정.
///
/// 프로젝트 설정은 소속 타깃 전체로 내려가므로 타깃마다 다시 붙이지 않는다.
/// 타깃 고유 설정이 필요하면 `moduleProject(additionalSettings:)` 로 덧붙인다.
public let hannunProjectSettings: Settings = .settings(base: .hannunBase)
