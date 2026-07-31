import Testing
@testable import PortfolioFeature

@Suite("PortfolioRootView")
struct PortfolioRootViewTests {
    @Test("루트 View 를 생성할 수 있다")
    @MainActor
    func canInstantiate() {
        _ = PortfolioRootView()
    }
}
