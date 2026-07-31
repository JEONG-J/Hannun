//
//  Project.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 디자인 토큰·Glass 헬퍼·공통 컴포넌트. 도메인 엔티티는 절대 보지 않는다.
///
/// `Colors.xcassets` 를 리소스로 선언해야 Tuist 가 `Bundle.module` 접근자를 만든다.
/// staticFramework 는 메인 번들에 리소스가 실리지 않으므로 `Color("...", bundle: .module)` 이 필수다.
let project = moduleProject(
    name: "HannunDesignSystem",
    bundleIdSuffix: "designsystem",
    resources: ["Resources/**"],
    dependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
    ]
)
