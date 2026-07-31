//
//  ContainerShape.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 카드·차트 컨테이너·리스트 그룹이 공유하는 클리핑 도형.
///
/// 고정 반경 대신 `ConcentricRectangle` 을 쓰는 이유는 바깥 컨테이너(디바이스 코너·시트 코너)와
/// 곡률을 동심으로 맞추기 위해서다. 부모 컨테이너가 없으면 `minimum` 값으로 떨어진다.
public extension Shape where Self == ConcentricRectangle {
    static func hannunContainer(radius: CGFloat = .radiusM) -> ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(radius)), isUniform: true)
    }
}
