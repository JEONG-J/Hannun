//
//  DIRegistration.swift
//  Hannun
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
import HannunCore
import HannunData
import HannunDomain
import SwiftData

/// Protocol → 구현체 등록을 모으는 지점. 앱 타깃만이 HannunData 를 알기 때문에
/// 이 파일이 구현체를 아는 유일한 곳이다.
enum DIRegistration {
    // MARK: - Function

    @MainActor
    static func registerAll(into container: DIContainer) {
        let modelContainer = makeModelContainer()

        #if DEBUG
        // 저장소를 만든 직후, 어떤 Repository 도 읽기 전에 넣어야 첫 화면부터 데이터가 보인다.
        DemoSeed.seedIfRequested(modelContainer)
        #endif

        registerServices(into: container, modelContainer: modelContainer)
        registerPortfolioUseCases(into: container)
        registerNetWorthUseCases(into: container)
        registerPerformanceUseCases(into: container)
        registerJournalUseCases(into: container)
    }

    /// 저장소를 열지 못하면 어떤 화면도 의미 있는 값을 보여줄 수 없으므로 즉시 멈춘다.
    private static func makeModelContainer() -> ModelContainer {
        do {
            return try HannunModelContainer.make()
        } catch {
            preconditionFailure("저장소를 초기화하지 못했습니다. \(error)")
        }
    }

    @MainActor
    private static func registerServices(
        into container: DIContainer,
        modelContainer: ModelContainer
    ) {
        // 시세와 환율은 같은 KIS 접근토큰을 쓴다. 조립을 한 번만 해야 토큰도 한 번만 발급된다.
        let market = MarketRepositories()

        container.register((any HoldingRepositoryProtocol).self) {
            HoldingRepository(modelContainer: modelContainer)
        }
        container.register((any CashFlowRepositoryProtocol).self) {
            CashFlowRepository(modelContainer: modelContainer)
        }
        container.register((any SnapshotRepositoryProtocol).self) {
            SnapshotRepository(modelContainer: modelContainer)
        }
        container.register((any BenchmarkRepositoryProtocol).self) {
            BenchmarkRepository(modelContainer: modelContainer)
        }
        container.register((any JournalRepositoryProtocol).self) {
            JournalRepository(modelContainer: modelContainer)
        }
        container.register((any MarketDataServiceProtocol).self) { market.marketData }
        container.register((any ExchangeRateServiceProtocol).self) { market.exchangeRate }
        // 기기 안에서 도는 모델이라 토큰도 세션도 공유할 게 없다 — 부를 때마다 새로 만든다.
        container.register((any JournalContentWriterProtocol).self) {
            OnDeviceJournalContentWriter()
        }
    }

    /// 팩토리는 컨테이너보다 오래 살 수 없으므로 `unowned` 로 잡아 순환 참조를 만들지 않는다.
    @MainActor
    private static func registerPortfolioUseCases(into container: DIContainer) {
        container.register((any FetchHoldingsUseCaseProtocol).self) { [unowned container] in
            FetchHoldingsUseCase(
                holdingRepository: container.resolve((any HoldingRepositoryProtocol).self),
                marketDataService: container.resolve((any MarketDataServiceProtocol).self)
            )
        }
        container.register((any SaveHoldingUseCaseProtocol).self) { [unowned container] in
            SaveHoldingUseCase(
                holdingRepository: container.resolve((any HoldingRepositoryProtocol).self)
            )
        }
        container.register((any DeleteHoldingUseCaseProtocol).self) { [unowned container] in
            DeleteHoldingUseCase(
                holdingRepository: container.resolve((any HoldingRepositoryProtocol).self)
            )
        }
        container.register((any ManageCashFlowUseCaseProtocol).self) { [unowned container] in
            ManageCashFlowUseCase(
                cashFlowRepository: container.resolve((any CashFlowRepositoryProtocol).self)
            )
        }
    }

    @MainActor
    private static func registerNetWorthUseCases(into container: DIContainer) {
        container.register((any FetchNetWorthUseCaseProtocol).self) { [unowned container] in
            FetchNetWorthUseCase(
                fetchHoldingsUseCase: container.resolve((any FetchHoldingsUseCaseProtocol).self)
            )
        }
        container.register((any FetchCategoryBreakdownUseCaseProtocol).self) {
            [unowned container] in
            FetchCategoryBreakdownUseCase(
                fetchNetWorthUseCase: container.resolve((any FetchNetWorthUseCaseProtocol).self)
            )
        }
    }

    @MainActor
    private static func registerPerformanceUseCases(into container: DIContainer) {
        container.register((any RecordSnapshotUseCaseProtocol).self) { [unowned container] in
            RecordSnapshotUseCase(
                snapshotRepository: container.resolve((any SnapshotRepositoryProtocol).self),
                fetchNetWorthUseCase: container.resolve((any FetchNetWorthUseCaseProtocol).self)
            )
        }
        container.register((any FetchNetWorthTrendUseCaseProtocol).self) { [unowned container] in
            FetchNetWorthTrendUseCase(
                snapshotRepository: container.resolve((any SnapshotRepositoryProtocol).self)
            )
        }
        container.register((any CalculateYTDReturnUseCaseProtocol).self) { [unowned container] in
            CalculateYTDReturnUseCase(
                snapshotRepository: container.resolve((any SnapshotRepositoryProtocol).self),
                cashFlowRepository: container.resolve((any CashFlowRepositoryProtocol).self),
                fetchNetWorthUseCase: container.resolve((any FetchNetWorthUseCaseProtocol).self)
            )
        }
        container.register((any CompareBenchmarkUseCaseProtocol).self) { [unowned container] in
            CompareBenchmarkUseCase(
                snapshotRepository: container.resolve((any SnapshotRepositoryProtocol).self),
                cashFlowRepository: container.resolve((any CashFlowRepositoryProtocol).self),
                benchmarkRepository: container.resolve((any BenchmarkRepositoryProtocol).self)
            )
        }
    }

    @MainActor
    private static func registerJournalUseCases(into container: DIContainer) {
        container.register((any FetchJournalUseCaseProtocol).self) { [unowned container] in
            FetchJournalUseCase(
                journalRepository: container.resolve((any JournalRepositoryProtocol).self)
            )
        }
        container.register((any SaveJournalUseCaseProtocol).self) { [unowned container] in
            SaveJournalUseCase(
                journalRepository: container.resolve((any JournalRepositoryProtocol).self)
            )
        }
        container.register((any DeleteJournalUseCaseProtocol).self) { [unowned container] in
            DeleteJournalUseCase(
                journalRepository: container.resolve((any JournalRepositoryProtocol).self)
            )
        }
        container.register((any DraftJournalContentUseCaseProtocol).self) { [unowned container] in
            DraftJournalContentUseCase(
                contentWriter: container.resolve((any JournalContentWriterProtocol).self)
            )
        }
    }
}
