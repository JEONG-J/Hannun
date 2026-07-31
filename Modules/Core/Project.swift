//
//  Project.swift
//  HannunCore
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 공유 커널. 의존성이 없는 잎 노드다 — 여기서 다른 모듈을 참조하는 순간 순환이 생긴다.
let project = moduleProject(
    name: "HannunCore",
    bundleIdSuffix: "core",
    includesTests: true
)
