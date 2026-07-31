//
//  Project.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 투자 성과 탭 (PM-1 ~ PM-4).
let project = featureProject(
    name: "PerformanceFeature",
    bundleIdSuffix: "performance",
    includesTests: true,
    testDependencies: [
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunDesignSystem", path: .relativeToRoot("Modules/DesignSystem")),
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
    ]
)
