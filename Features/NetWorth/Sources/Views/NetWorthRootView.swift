//
//  NetWorthRootView.swift
//  NetWorthFeature
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// 순자산 탭 루트 (NW-1 ~ NW-4).
///
/// 앱 셸이 인자 없이 만들기 때문에 컨테이너를 환경에서 꺼내 안쪽 화면에 넘긴다 —
/// ViewModel 소유는 컨테이너를 인자로 받는 `NetWorthScreen` 이 맡는다.
public struct NetWorthRootView: View {

    // MARK: - Property

    @Environment(DIContainer.self) private var container

    // MARK: - Body

    public init() {}

    public var body: some View {
        NetWorthScreen(container: container)
    }
}
