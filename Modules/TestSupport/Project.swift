//
//  Project.swift
//  HannunTestSupport
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 테스트 타깃 전용 fake·fixture. 테스트 타깃만 링크하므로 앱 바이너리에 들어가지 않는다.
///
/// 프리뷰·개발용 mock 은 여기가 아니라 각 모듈 안에 `#if DEBUG` 로 둔다.
let project = moduleProject(
    name: "HannunTestSupport",
    bundleIdSuffix: "testsupport",
    dependencies: [
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
    ]
)
