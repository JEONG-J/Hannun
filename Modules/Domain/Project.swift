//
//  Project.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// SwiftData 엔티티·Repository/Service 프로토콜·UseCase.
///
/// 네 탭이 같은 엔티티를 교차 참조하고 SwiftData 스키마가 단일 `ModelContainer` 로 묶이므로
/// Feature 별로 쪼개지 않고 여기서 공유한다. SwiftUI / DesignSystem 을 import 하지 않는다.
let project = moduleProject(
    name: "HannunDomain",
    bundleIdSuffix: "domain",
    dependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunTestSupport", path: .relativeToRoot("Modules/TestSupport")),
    ]
)
