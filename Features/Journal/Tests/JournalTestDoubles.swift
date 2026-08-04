//
//  JournalTestDoubles.swift
//  JournalFeatureTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import HannunTestSupport

/// 실패 경로 전용 대역. In-Memory 저장소는 성공만 하므로 실패는 여기서 만든다.
struct FailingFetchJournalUseCase: FetchJournalUseCaseProtocol {
    let error: AppError

    func execute(holdingID: UUID?) async throws -> [JournalRecord] {
        throw error
    }
}

struct FailingSaveJournalUseCase: SaveJournalUseCaseProtocol {
    let error: AppError

    func execute(_ entry: JournalRecord) async throws {
        throw error
    }
}

struct FailingDeleteJournalUseCase: DeleteJournalUseCaseProtocol {
    let error: AppError

    func execute(id: UUID) async throws {
        throw error
    }
}

struct FailingFetchHoldingsUseCase: FetchHoldingsUseCaseProtocol {
    let error: AppError

    func execute(
        category: AssetCategory?,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> [HoldingValuation] {
        throw error
    }
}

/// 초안 생성기 대역. 실제 구현은 FoundationModels 를 타므로 테스트에서 부를 수 없다 —
/// 여기서는 화면이 **무엇을 재료로 넘겼는지**만 받아 둔다.
actor SpyDraftJournalContentUseCase: DraftJournalContentUseCaseProtocol {
    private let readiness: JournalContentAvailability
    private let draft: Result<String, AppError>

    private(set) var lastRequest: JournalContentRequest?

    init(
        readiness: JournalContentAvailability = .ready,
        draft: Result<String, AppError> = .success(SpyDraftJournalContentUseCase.sampleDraft)
    ) {
        self.readiness = readiness
        self.draft = draft
    }

    static let sampleDraft = "환율 부담이 커져 반도체 비중을 줄였다."

    func availability() async -> JournalContentAvailability {
        readiness
    }

    func execute(_ request: JournalContentRequest) async throws -> String {
        lastRequest = request
        return try draft.get()
    }
}

/// 테스트가 공유하는 매매일지 픽스처 조립기.
enum JournalFixture {
    static let samsung = SampleRecords.holding(
        category: .domesticStock,
        name: "삼성전자",
        ticker: "005930",
        quantity: 10,
        averagePrice: 70_000
    )

    static let apple = SampleRecords.holding(
        category: .overseasStock,
        name: "AAPL",
        ticker: "AAPL",
        currency: .usd,
        quantity: 5,
        averagePrice: 180
    )

    static let holdings: [HoldingRecord] = [samsung, apple]

    /// 매번 새 UUID 가 생기지 않도록 한 번만 만든다 — 테스트끼리 같은 식별자를 봐야 한다.
    static let entries: [JournalRecord] = [
        SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 7, 20),
            title: "현금 비중 유지",
            content: "지수가 고점이라 관망한다."
        ),
        SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 7, 25),
            title: "반도체 비중 축소",
            content: "환율이 밀릴 것 같아 정리했다.",
            holdingIDs: [samsung.id]
        ),
        SampleRecords.journal(
            writtenAt: SampleRecords.day(2026, 7, 27),
            title: "애플 추가 매수",
            content: "실적 발표 전 분할 매수.",
            holdingIDs: [apple.id]
        ),
    ]

    static func fetchJournal(_ entries: [JournalRecord]) -> any FetchJournalUseCaseProtocol {
        FetchJournalUseCase(journalRepository: InMemoryJournalRepository(entries))
    }

    static func fetchHoldings(
        _ holdings: [HoldingRecord] = JournalFixture.holdings
    ) -> any FetchHoldingsUseCaseProtocol {
        FetchHoldingsUseCase(
            holdingRepository: InMemoryHoldingRepository(holdings),
            marketDataService: FixedPriceMarketDataService()
        )
    }
}
