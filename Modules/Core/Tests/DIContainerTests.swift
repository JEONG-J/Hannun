//
//  DIContainerTests.swift
//  HannunCoreTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
@testable import HannunCore

private protocol QuoteLoading: AnyObject {
    var source: String { get }
}

private final class LiveQuoteLoader: QuoteLoading {
    let source = "live"
}

private final class StubQuoteLoader: QuoteLoading {
    let source = "stub"
}

@Suite("DIContainer")
@MainActor
struct DIContainerTests {
    @Test("등록한 팩토리의 구현체를 돌려준다")
    func resolvesRegisteredImplementation() {
        let container = DIContainer()
        container.register((any QuoteLoading).self) { LiveQuoteLoader() }

        #expect(container.resolve((any QuoteLoading).self).source == "live")
    }

    @Test("해석한 인스턴스를 보관해 같은 인스턴스를 돌려준다")
    func cachesResolvedInstance() {
        let container = DIContainer()
        container.register((any QuoteLoading).self) { LiveQuoteLoader() }

        let firstResolved = container.resolve((any QuoteLoading).self)
        let secondResolved = container.resolve((any QuoteLoading).self)

        #expect(firstResolved === secondResolved)
    }

    @Test("resetCache 후에는 새 인스턴스를 만든다")
    func resetCacheDropsInstance() {
        let container = DIContainer()
        container.register((any QuoteLoading).self) { LiveQuoteLoader() }

        let firstInstance = container.resolve((any QuoteLoading).self)
        container.resetCache()

        #expect(container.resolve((any QuoteLoading).self) !== firstInstance)
    }

    @Test("같은 타입을 다시 등록하면 나중 등록이 이긴다")
    func reregistrationReplacesPrevious() {
        let container = DIContainer()
        container.register((any QuoteLoading).self) { LiveQuoteLoader() }
        _ = container.resolve((any QuoteLoading).self)

        container.register((any QuoteLoading).self) { StubQuoteLoader() }

        #expect(container.resolve((any QuoteLoading).self).source == "stub")
    }
}
