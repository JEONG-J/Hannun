//
//  AccessoryLayout.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 탭바 하단 액세서리가 지금 어느 크기로 그려지는지.
///
/// SwiftUI 의 `TabViewBottomAccessoryPlacement` 를 그대로 넘기지 않고 한 겹 옮겨 적는다.
/// 그 키는 **읽기 전용**이라 `TabView` 밖에서는 언제나 `.expanded` 다 — 프리뷰에도 테스트에도
/// `TabView` 가 없으니 축약 분기를 화면에 띄울 방법이 없고, 결국 아무도 못 본 채로 나간다.
/// 우리 값으로 받아 두면 `accessoryLayout(_:)` 으로 강제해 눈으로 확인할 수 있다.
public enum AccessoryLayout: CaseIterable, Sendable {
    /// 탭바가 펼쳐진 기본 상태. 캡슐에 라벨·칩을 그대로 담는다.
    case expanded
    /// 탭바가 최소화돼 캡슐이 한 줄로 줄어든 상태. 부차 요소는 접거나 짧게 줄인다.
    case inline
}

public extension EnvironmentValues {
    /// 액세서리 내용이 읽는 배치 상태. `BottomAccessory` 가 주입한다.
    ///
    /// 내용 쪽에서 `tabViewBottomAccessoryPlacement` 를 직접 읽지 않는다 — 그 키는
    /// 액세서리 컨테이너 안에서만 값이 서고, 밖에 놓인 뷰가 읽으면 조용히 `.expanded` 가
    /// 나와 틀린 분기를 탄다. 컨테이너가 한 번 읽어 내려보내는 이 값만 본다.
    @Entry var accessoryLayout: AccessoryLayout = .expanded
}

public extension View {
    /// 배치 상태를 강제한다. **프리뷰·테스트 전용**이다.
    ///
    /// 앱에서는 `BottomAccessory` 가 시스템 placement 를 옮겨 적으므로 붙일 일이 없다.
    /// 붙이면 시스템 값을 덮어써 실제와 다른 모습이 나온다.
    ///
    /// ```swift
    /// #Preview("순자산 액세서리 · 축약") {
    ///     NetWorthAccessory(viewModel: .preview)
    ///         .accessoryLayout(.inline)
    /// }
    /// ```
    func accessoryLayout(_ layout: AccessoryLayout) -> some View {
        environment(\.accessoryLayoutOverride, layout)
    }
}

extension EnvironmentValues {
    /// 프리뷰가 심어 둔 강제값. `BottomAccessory` 만 읽고, 없으면 시스템 placement 를 따른다.
    @Entry var accessoryLayoutOverride: AccessoryLayout?
}
