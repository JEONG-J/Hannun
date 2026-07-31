//
//  Workspace.swift
//  Hannun
//
//  Created by euijjang97 on 8/1/26.
//

import ProjectDescription

/// 모듈 하나 = 프로젝트 하나. 워크스페이스가 이들을 묶는다.
///
/// `Modules/*` · `Features/*` 는 glob 이라 **새 모듈 디렉터리에 `Project.swift` 만 두면
/// 자동으로 포함된다** — 이 파일을 고칠 일은 거의 없다.
///
/// 스킴은 전부 Tuist 자동 생성이다. 타깃마다 동명의 스킴이 생기고, 프로젝트를 가로질러
/// 전 타깃을 빌드·테스트하는 `Hannun-Workspace` 스킴이 함께 생긴다 (`make test-all` 이 쓴다).
let workspace = Workspace(
    name: "Hannun",
    projects: [
        ".",
        "Modules/*",
        "Features/*",
    ]
)
