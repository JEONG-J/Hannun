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

/// 큰 제목 아래 한 줄(`navigationSubtitle`)이 말할 내용 (디자인 문서 §4.0).
///
/// 문구가 아니라 **무엇을 말할지**만 정한다 — 같은 상태를 부르는 이름은 자리가 바뀌면 같이
/// 바뀌지만(액세서리 → 제목 아래), 목록이 어떤 상태인가는 그대로다. 문자열까지 여기서
/// 굳히면 자리를 옮길 때마다 ViewModel 을 건드려야 한다.
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

    /// 지금 고른 종목의 이름. 필터가 없거나 그 사이 종목이 지워졌으면 `nil` 이다.
    var selectedHoldingName: String? {
        guard let selectedHoldingID else { return nil }
        return holdingTagsState.value?.first { $0.id == selectedHoldingID }?.name
    }

    /// 지금 걸려 있는 필터의 이름. 종목 필터가 검색어보다 앞선다 — 종목은 툴바 버튼이
    /// 채운 아이콘으로 계속 드러내지만 검색어는 접히면 자취가 옅어져서, 둘 다 걸렸을 때
    /// 화면에서 덜 보이는 쪽을 액세서리가 대신 말한다.
    private var filterName: String? {
        if let selectedHoldingName { return selectedHoldingName }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? nil : keyword
    }

    /// 일지에 달린 종목 식별자를 실제 보유 종목으로 되돌린다.
    /// 찾지 못한 태그는 버린다 — 종목이 지워졌다는 뜻이다.
    ///
    /// 이름만 돌려주지 않는 이유는 태그 캡슐이 분류색을 입기 때문이다. 다만 화면에 쓸 표시용
    /// 값(`JournalTag`)으로 바꾸는 건 View 가 한다 — ViewModel 이 디자인 시스템 타입을 만들면
    /// 캡슐 모양이 바뀔 때마다 상태 코드가 따라 움직인다.
    func taggedHoldings(for entry: JournalRecord) -> [HoldingRecord] {
        let holdings = holdingTagsState.value ?? []
        return entry.holdingIDs.compactMap { holdingID in
            holdings.first { $0.id == holdingID }
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
