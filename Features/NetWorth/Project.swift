//
//  Project.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 순자산 탭 (NW-1 ~ NW-4).
let project = featureProject(
    name: "NetWorthFeature",
    bundleIdSuffix: "networth",
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunTestSupport", path: .relativeToRoot("Modules/TestSupport")),
    ]
)
