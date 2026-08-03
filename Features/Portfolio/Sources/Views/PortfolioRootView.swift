//
//  PortfolioRootView.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// 포트폴리오 탭 루트 (PF-1 ~ PF-6).
///
/// 앱 셸이 인자 없이 만들기 때문에 컨테이너를 환경에서 꺼내 안쪽 화면에 넘긴다 —
/// 라우터·ViewModel 소유는 컨테이너를 인자로 받는 `PortfolioScreen` 이 맡는다.
public struct PortfolioRootView: View {

    // MARK: - Property

    @Environment(DIContainer.self) private var container
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Body

    public init() {}

    public var body: some View {
        PortfolioScreen(container: container, errorHandler: errorHandler)
    }
}
