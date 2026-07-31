import Testing
@testable import HannunCore

@Suite("Loadable")
struct LoadableTests {
    @Test("loaded 만 value 를 돌려준다", arguments: [
        Loadable<Int>.idle, .loading, .failed(.unauthorized),
    ])
    func nonLoadedHasNoValue(state: Loadable<Int>) {
        #expect(state.value == nil)
    }

    @Test("loaded 는 연관값을 그대로 노출한다")
    func loadedExposesValue() throws {
        let value = try #require(Loadable.loaded(42).value)
        #expect(value == 42)
    }
}
