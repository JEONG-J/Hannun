//
//  JournalListViewModel.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 목록 자리에 일지 대신 무엇을 그릴지.
enum JournalListPlaceholder: Equatable, Sendable {
    /// 저장된 일지가 한 건도 없다 (JR-1 빈 상태).
    case noEntry
    /// 종목 필터·검색어가 전부 걸러냈다.
    case noMatch
}

/// 매매일지 목록 화면 상태 (JR-1, JR-4).
@MainActor
@Observable
final class JournalListViewModel {
    // MARK: - Property

    private(set) var entriesState: Loadable<[JournalRecord]> = .idle

    /// 필터 칩에 쓰는 보유 종목. 실패해도 일지 자체는 읽을 수 있어야 하므로
    /// 화면 전체 상태와 분리해 둔다.
    private(set) var holdingTagsState: Loadable<[HoldingRecord]> = .idle

    private(set) var selectedHoldingID: UUID?

    var searchText = ""

    private let fetchJournal: any FetchJournalUseCaseProtocol
    private let fetchHoldings: any FetchHoldingsUseCaseProtocol

    /// 검색어까지 반영한 최종 표시 목록. 종목 필터는 저장소 조회 단계에서 이미 적용돼 있다.
    var visibleEntries: [JournalRecord] {
        guard let entries = entriesState.value else { return [] }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return entries }

        return entries.filter { entry in
            entry.title.localizedStandardContains(keyword)
                || entry.content.localizedStandardContains(keyword)
        }
    }

    var placeholder: JournalListPlaceholder? {
        guard let entries = entriesState.value, visibleEntries.isEmpty else { return nil }

        let isUnfiltered = selectedHoldingID == nil && searchText.isEmpty
        return entries.isEmpty && isUnfiltered ? .noEntry : .noMatch
    }

    /// 일지에 달린 종목 식별자를 화면에 보여줄 종목명으로 바꾼다.
    /// 이름을 못 찾은 태그는 그리지 않는다 — 종목이 지워졌다는 뜻이다.
    func tagNames(for entry: JournalRecord) -> [String] {
        let holdings = holdingTagsState.value ?? []
        return entry.holdingIDs.compactMap { holdingID in
            holdings.first { $0.id == holdingID }?.name
        }
    }

    // MARK: - Function

    init(
        fetchJournal: any FetchJournalUseCaseProtocol,
        fetchHoldings: any FetchHoldingsUseCaseProtocol
    ) {
        self.fetchJournal = fetchJournal
        self.fetchHoldings = fetchHoldings
    }

    func load() async {
        await loadEntries()
        await loadHoldingTags()
    }

    func reload() async {
        await loadEntries()
    }

    /// 종목 필터를 바꾼다. `nil` 이면 전체 (JR-4).
    func selectHolding(_ holdingID: UUID?) async {
        guard selectedHoldingID != holdingID else { return }

        selectedHoldingID = holdingID
        await loadEntries()
    }

    private func loadEntries() async {
        entriesState = .loading
        do {
            let entries = try await fetchJournal.execute(holdingID: selectedHoldingID)
            entriesState = .loaded(entries)
        } catch {
            entriesState = .failed(AppError(narrowing: error))
        }
    }

    private func loadHoldingTags() async {
        holdingTagsState = .loading
        do {
            let valuations = try await fetchHoldings.execute(
                category: nil,
                baseCurrency: .krw,
                exchangeRate: Constants.tagOnlyExchangeRate
            )
            holdingTagsState = .loaded(valuations.map(\.holding))
        } catch {
            holdingTagsState = .failed(AppError(narrowing: error))
        }
    }
}

fileprivate enum Constants {
    /// 태그 칩에는 종목명만 쓰고 평가금액을 읽지 않아 환산 결과가 화면에 나타나지 않는다.
    /// 종목명만 돌려주는 조회 경로가 생기면 이 상수는 사라진다.
    static let tagOnlyExchangeRate = ExchangeRate(krwPerUSD: 1)
}
