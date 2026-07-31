//
//  Project.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 매매일지 탭 (JR-1 ~ JR-4).
let project = featureProject(
    name: "JournalFeature",
    bundleIdSuffix: "journal",
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunTestSupport", path: .relativeToRoot("Modules/TestSupport")),
    ]
)
