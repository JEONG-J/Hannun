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
        container.register((any MarketDataServiceProtocol).self) {
            MarketDataRepository()
        }
        container.register((any ExchangeRateServiceProtocol).self) {
            ExchangeRateRepository()
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
    }
}
