import SwiftUI

@main
struct HannunApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(router)
        }
    }
}
