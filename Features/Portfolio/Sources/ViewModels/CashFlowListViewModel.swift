//
//  CashFlowListViewModel.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 한 달치 입출금 기록 묶음.
struct CashFlowMonthSection: Identifiable, Equatable {
    let month: Date
    let title: String
    let events: [CashFlowRecord]

    var id: Date { month }
}

/// 입출금 기록 목록 (PF-5, PF-6).
@MainActor
@Observable
final class CashFlowListViewModel {

    // MARK: - Property

    private let manageCashFlow: any ManageCashFlowUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let calendar: Calendar

    private(set) var events: Loadable<[CashFlowRecord]> = .idle
    var alertPrompt: AlertPrompt?

    /// 최신 달이 위로 오도록 내림차순 정렬한다.
    var sections: [CashFlowMonthSection] {
        guard let loaded = events.value else { return [] }

        let grouped = Dictionary(grouping: loaded) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.occurredOn))
                ?? event.occurredOn
        }

        return grouped
            .map { month, events in
                CashFlowMonthSection(
                    month: month,
                    title: month.formatted(.dateTime.year().month()),
                    events: events.sorted { $0.occurredOn > $1.occurredOn }
                )
            }
            .sorted { $0.month > $1.month }
    }

    var isEmpty: Bool { events.value?.isEmpty == true }

    // MARK: - Function

    init(
        manageCashFlow: any ManageCashFlowUseCaseProtocol,
        errorHandler: ErrorHandler,
        calendar: Calendar = .current
    ) {
        self.manageCashFlow = manageCashFlow
        self.errorHandler = errorHandler
        self.calendar = calendar
    }

    func load() async {
        guard case .idle = events else { return }

        events = .loading
        await reload()
    }

    func refresh() async {
        await reload()
    }

    func requestDelete(_ event: CashFlowRecord) {
        let title = CashFlowKindText.title(for: event.kind)

        alertPrompt = AlertPrompt(
            title: "\(title) 기록 삭제",
            message: Constants.deleteMessage,
            confirmTitle: "삭제",
            isDestructive: true,
            confirmAction: { [weak self] in
                Task { await self?.delete(id: event.id) }
            }
        )
    }

    /// 확인 다이얼로그가 승인한 뒤에만 불린다.
    func delete(id: UUID) async {
        do {
            try await manageCashFlow.delete(id: id)
            await reload()
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: Constants.featureName,
                    action: "입출금 기록 삭제",
                    retryAction: { [weak self] in await self?.delete(id: id) }
                )
            )
        }
    }

    private func reload() async {
        do {
            events = .loaded(try await manageCashFlow.fetchAll())
        } catch {
            events = .failed(AppError(narrowing: error))
        }
    }
}

fileprivate enum Constants {
    static let featureName = "포트폴리오"
    static let deleteMessage = "이 기록이 사라지면 성과 탭의 수익률도 함께 바뀝니다."
}
