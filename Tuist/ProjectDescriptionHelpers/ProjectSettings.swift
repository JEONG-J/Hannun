//
//  ProjectSettings.swift
//  ProjectDescriptionHelpers
//
//  Created by euijjang97 on 7/31/26.
//

import ProjectDescription

/// TODO: 팀 organization identifier 확정 후 교체
public let bundleIdPrefix = "com.jeong.hannun"
public let hannunOrganizationName = "Hannun"
public let hannunDestinations: Destinations = [.iPhone, .iPad]
public let hannunDeploymentTargets: DeploymentTargets = .iOS("26.0")

public extension SettingsDictionary {
    static var hannunBase: SettingsDictionary {
        [
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
