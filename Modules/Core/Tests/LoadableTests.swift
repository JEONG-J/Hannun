//
//  LoadableTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 7/31/26.
//

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

    @Test("isLoading 은 loading 에서만 참이다")
    func isLoadingOnlyWhileLoading() {
        #expect(Loadable<Int>.loading.isLoading)
        #expect(!Loadable<Int>.idle.isLoading)
        #expect(!Loadable.loaded(42).isLoading)
        #expect(!Loadable<Int>.failed(.unauthorized).isLoading)
    }

    @Test("error 는 failed 의 연관값만 돌려준다")
    func errorOnlyFromFailed() throws {
        let error = try #require(Loadable<Int>.failed(.network("timeout")).error)
        #expect(error == .network("timeout"))
        #expect(Loadable.loaded(42).error == nil)
    }

    @Test("map 은 loaded 값만 변환한다")
    func mapTransformsLoadedValue() {
        #expect(Loadable.loaded(42).map({ $0 * 2 }) == .loaded(84))
    }

    @Test("map 은 loaded 가 아닌 상태를 그대로 유지한다")
    func mapKeepsNonLoadedState() {
        #expect(Loadable<Int>.idle.map({ $0 * 2 }) == .idle)
        #expect(Loadable<Int>.loading.map({ $0 * 2 }) == .loading)
        #expect(Loadable<Int>.failed(.unauthorized).map({ $0 * 2 }) == .failed(.unauthorized))
    }
}
