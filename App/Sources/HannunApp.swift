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

    init() {
        let container = DIContainer()
        DIRegistration.registerAll(into: container)
        _container = State(initialValue: container)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(router)
                .environment(\.appRouter, router)
                .environment(\.tabAccessoryHost, accessoryHost)
                .environment(container)
                .environment(errorHandler)
                .errorAlert(errorHandler)
        }
    }
}
