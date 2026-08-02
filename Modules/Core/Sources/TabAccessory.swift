//
//  TabAccessory.swift
//  HannunCore
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// 탭바 하단 액세서리 조율자.
///
/// 액세서리는 `TabView` **하나에만** 붙고(UI 스펙 §3.1) 그 `TabView` 는 앱 타깃에 있다.
/// 반면 액세서리에 담을 내용은 탭 화면의 상태(선택된 통화·벤치마크 등)를 읽어야 하므로
/// Feature 안에 있어야 한다. 양쪽을 직접 잇는 방법이 없으니 — Feature 는 앱 타깃을
/// import 할 수 없다 — Feature 가 자기 몫을 여기 등록하고 앱 셸이 현재 탭의 등록물만 꺼내 그린다.
///
/// 등록물을 `AnyView` 로 지우는 이유: 탭마다 액세서리 타입이 다른데 한 저장소에 담아야 한다.
/// 지워도 Observation 추적은 살아 있다 — 등록 클로저가 Feature 의 `@Observable` ViewModel 을
/// 참조로 붙잡으므로, 그 안의 값이 바뀌면 액세서리도 다시 그려진다.
@MainActor
@Observable
public final class TabAccessoryHost {
    // MARK: - Property

    private var providers: [AppTab: () -> AnyView] = [:]

    // MARK: - Function

    public init() {}

    /// 해당 탭이 공급하는 액세서리. 등록이 없으면 nil 이고 앱 셸은 아무것도 그리지 않는다.
    public func content(for tab: AppTab) -> AnyView? {
        providers[tab]?()
    }

    /// 탭 하나의 공급자를 갈아끼운다. 같은 탭을 다시 등록하면 최신 것만 남는다.
    public func register(_ tab: AppTab, content: @escaping () -> AnyView) {
        providers[tab] = content
    }

    public func unregister(_ tab: AppTab) {
        providers[tab] = nil
    }
}

public extension EnvironmentValues {
    /// 앱 타깃이 주입한다. 프리뷰처럼 앱 셸이 없는 환경에서는 nil 이라 등록이 조용히 무시된다.
    @Entry var tabAccessoryHost: TabAccessoryHost?
}

public extension View {
    /// 이 화면을 담은 탭의 하단 액세서리 내용을 공급한다.
    ///
    /// 탭의 **루트 View 에만** 붙인다. 액세서리는 화면이 아니라 탭에 속하므로(§3.1)
    /// 상세 화면을 push 해도 그대로 남아 있어야 한다.
    ///
    /// ```swift
    /// PerformanceContentView(viewModel: viewModel)
    ///     .tabAccessory(.performance) {
    ///         BenchmarkAccessory(viewModel: viewModel)
    ///     }
    /// ```
    ///
    /// - Important: 클로저 안에는 **참조(ViewModel·Router)만** 넘긴다. 이 클로저는 화면이
    ///   처음 나타날 때 한 번 붙잡혀 계속 쓰이므로, 바깥에서 값을 꺼내 인자로 넘기면
    ///   (`freshness: viewModel.freshness`) 그 시점 값이 굳어 이후 갱신이 반영되지 않는다.
    ///   액세서리가 참조를 받아 **자기 body 안에서** 읽어야 Observation 이 추적한다.
    func tabAccessory<Accessory: View>(
        _ tab: AppTab,
        @ViewBuilder content: @escaping () -> Accessory
    ) -> some View {
        modifier(TabAccessoryModifier(tab: tab, accessory: content))
    }
}

private struct TabAccessoryModifier<Accessory: View>: ViewModifier {
    // MARK: - Property

    @Environment(\.tabAccessoryHost) private var host

    let tab: AppTab
    let accessory: () -> Accessory

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .onAppear {
                // 등록 해제는 하지 않는다. 탭 전환 시 onDisappear 가 먼저 도는 순간
                // 액세서리가 비었다가 다시 차는 깜빡임이 생기고, 탭별로 키가 갈리므로
                // 남아 있어도 다른 탭을 침범하지 않는다.
                host?.register(tab) { AnyView(accessory()) }
            }
    }
}
