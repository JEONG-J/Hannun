//
//  Project.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 포트폴리오 탭 (PF-1 ~ PF-6).
let project = featureProject(
    name: "PortfolioFeature",
    bundleIdSuffix: "portfolio",
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunTestSupport", path: .relativeToRoot("Modules/TestSupport")),
    ]
)
