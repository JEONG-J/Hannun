//
//  Project.swift
//  SettingsFeature
//
//  Created by euijjang97 on 8/8/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 설정 화면. 지금은 시세 앱키 하나만 다룬다.
let project = featureProject(
    name: "SettingsFeature",
    bundleIdSuffix: "settings",
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
    ]
)
