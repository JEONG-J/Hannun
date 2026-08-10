//
//  HannunApp.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

@main
struct HannunApp: App {
    @State private var router = AppRouter()
    @State private var container: DIContainer
    @State private var errorHandler = ErrorHandler()
    @State private var accessoryHost = TabAccessoryHost()

    /// 스플래시를 걷었는지. 창이 만들어질 때 한 번만 뒤집힌다 — 백그라운드에서 돌아올 때는
    /// `.task` 가 다시 돌지 않으므로 앱을 새로 켤 때만 보인다.
    @State private var isSplashFinished = false

    init() {
        let container = DIContainer()
        DIRegistration.registerAll(into: container)
        _container = State(initialValue: container)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environment(router)
                    .environment(\.appRouter, router)
                    .environment(\.tabAccessoryHost, accessoryHost)
                    .environment(container)
                    .environment(errorHandler)
                    .errorAlert(errorHandler)

                if !isSplashFinished {
                    SplashOverlay()
                        .transition(.opacity)
                }
            }
            // 크로스페이드다. Reduce Motion 이 스프링·슬라이드를 대체하라고 요구하는 그
            // 형태라 따로 분기하지 않는다.
            .animation(.easeInOut(duration: Constants.splashFadeDuration), value: isSplashFinished)
            // 덮여 있는 동안 아래 탭 화면은 이미 살아서 첫 조회를 돌린다 — 걷어내는 순간
            // 빈 화면이 아니라 값이 들어찬 화면이 나온다.
            .task {
                try? await Task.sleep(for: Constants.splashDuration)
                isSplashFinished = true
            }
        }
    }
}

fileprivate enum Constants {
    /// 런치 화면이 걷힌 뒤부터 센다 — 로고가 화면에 머무는 총 시간은 앱이 첫 프레임을
    /// 그리기까지 걸린 만큼 이보다 조금 길다.
    static let splashDuration: Duration = .seconds(2)
    static let splashFadeDuration: TimeInterval = 0.35
}
