//
//  JournalRootView.swift
//  JournalFeature
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// 매매일지 탭 루트 (JR-1 ~ JR-4).
///
/// 화면을 직접 그리지 않고 Environment 에 들어 있는 의존성만 꺼내 넘긴다 —
/// View 의 `init` 은 Environment 를 읽을 수 없어서 ViewModel 을 소유하는 쪽을 한 겹 안으로 민다.
public struct JournalRootView: View {
    // MARK: - Property

    @Environment(DIContainer.self) private var container
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Body

    public init() {}

    public var body: some View {
        JournalListView(container: container, errorHandler: errorHandler)
    }
}
