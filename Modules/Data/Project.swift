//
//  Project.swift
//  HannunData
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// Repository 구현체·`ModelContainer` 팩토리·`Endpoint`/`NetworkClient`·DTO·시세 캐시.
///
/// 전송 계층 타입은 이 타깃 **내부**에만 존재한다 (`internal`). 외부에 `public` 인 것은
/// Repository 구현체뿐이라, 앱 타깃만이 구현체를 알고 나머지는 프로토콜만 본다.
let project = moduleProject(
    name: "HannunData",
    bundleIdSuffix: "data",
    dependencies: [
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunTestSupport", path: .relativeToRoot("Modules/TestSupport")),
    ]
)
