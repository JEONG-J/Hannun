//
//  Tuist.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import ProjectDescription

// 금지 간선(암묵적 의존성)은 Tuist 4.202.6 기준 생성 옵션이 아니라 검사 명령으로 차단한다.
//   make inspect  →  tuist inspect dependencies --only implicit
// (구 `generationOptions: .options(enforceExplicitDependencies: true)` 는 deprecated)
let tuist = Tuist(
    project: .tuist(
        swiftVersion: nil,
        generationOptions: .options(
            defaultConfiguration: "Debug"
        )
    )
)
