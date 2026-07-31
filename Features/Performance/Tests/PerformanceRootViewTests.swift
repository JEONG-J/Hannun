import Testing
@testable import PerformanceFeature

@Suite("PerformanceRootView")
struct PerformanceRootViewTests {
    @Test("루트 View 를 생성할 수 있다")
    @MainActor
    func canInstantiate() {
        _ = PerformanceRootView()
    }
}
