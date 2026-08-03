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

/// 하단 액세서리 왼쪽 한 줄이 말할 내용 (디자인 문서 §4.0).
///
/// 문구가 아니라 **무엇을 말할지**만 정한다 — 축약 여부에 따라 같은 뜻을 다른 길이로 적어야
/// 해서 문자열까지 여기서 굳히면 뷰가 다시 분해해야 한다.
enum JournalListCaption: Equatable, Sendable {

    /// 아직 한 건도 없다. 이 줄이 곧 빈 상태의 CTA 다.
    case empty

    /// 종목 필터나 검색어가 걸린 상태에서 남은 건수.
    case filtered(name: String, count: Int)

    /// 필터가 없을 때의 이번 달 기록 수.
    case thisMonth(count: Int)

    /// 이번 달에는 없지만 예전 기록은 있을 때의 전체 건수.
    ///
    /// "이번 달 0건"은 목록에 일지가 뻔히 보이는데도 아무것도 없다고 읽힌다. 달을 넘긴
    /// 직후에 특히 그렇다 — 매달 1일마다 스트립이 0으로 돌아간다.
    case total(count: Int)
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
    private let calendar: Calendar
    private let now: () -> Date

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

    /// 아직 목록을 못 받아온 동안에는 `nil` — 0건이라고 단정하면 로딩 중에 빈 상태 CTA 가
    /// 잠깐 스쳐 지나간다.
    var caption: JournalListCaption? {
        guard let entries = entriesState.value else { return nil }

        if let filterName {
            return .filtered(name: filterName, count: visibleEntries.count)
        }

        guard !entries.isEmpty else { return .empty }

        let thisMonthCount = entries.filter { isInCurrentMonth($0.writtenAt) }.count
        return thisMonthCount > 0
            ? .thisMonth(count: thisMonthCount)
            : .total(count: entries.count)
    }

    /// 지금 걸려 있는 필터의 이름. 종목 필터가 검색어보다 앞선다 — 칩은 화면에 그대로
    /// 보이지만 검색어는 키보드를 내리면 사라져서, 둘 다 걸렸을 때 더 오래 남는 쪽이다.
    private var filterName: String? {
        if let selectedHoldingID,
           let name = holdingTagsState.value?.first(where: { $0.id == selectedHoldingID })?.name {
            return name
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? nil : keyword
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
        fetchHoldings: any FetchHoldingsUseCaseProtocol,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.fetchJournal = fetchJournal
        self.fetchHoldings = fetchHoldings
        self.calendar = calendar
        self.now = now
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

    private func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: now(), toGranularity: .month)
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
