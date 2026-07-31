//
//  CashFlowEditorViewModel.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 입출금 기록 추가·수정 sheet (PF-5, PF-6).
@MainActor
@Observable
final class CashFlowEditorViewModel {

    // MARK: - Property

    private let manageCashFlow: any ManageCashFlowUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let editingEvent: CashFlowRecord?

    private(set) var submission: Loadable<CashFlowRecord> = .idle

    var occurredOn: Date
    var amountText: String
    var currency: Currency
    var kind: CashFlowKind
    var memo: String

    var isEditing: Bool { editingEvent != nil }

    var title: String { isEditing ? Constants.editTitle : Constants.createTitle }

    var canSave: Bool { amount != nil }

    var isSaving: Bool { submission.isLoading }

    var didSave: Bool { submission.value != nil }

    var validationMessage: String? { submission.error?.userMessage }

    private var amount: Decimal? {
        DecimalInput.value(from: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    // MARK: - Function

    init(
        manageCashFlow: any ManageCashFlowUseCaseProtocol,
        errorHandler: ErrorHandler,
        mode: CashFlowEditorMode,
        now: Date = Date()
    ) {
        self.manageCashFlow = manageCashFlow
        self.errorHandler = errorHandler

        let event = mode.editingEvent
        editingEvent = event

        occurredOn = event?.occurredOn ?? now
        amountText = DecimalInput.text(from: event?.amount)
        currency = event?.currency ?? .krw
        kind = event?.kind ?? .deposit
        memo = event?.memo ?? ""
    }

    func save() async {
        guard let amount else { return }

        let record = CashFlowRecord(
            id: editingEvent?.id ?? UUID(),
            occurredOn: occurredOn,
            amount: amount,
            currency: currency,
            kind: kind,
            memo: memo
        )

        submission = .loading

        do {
            try await manageCashFlow.save(record)
            submission = .loaded(record)
        } catch AppError.validation(let message) {
            submission = .failed(.validation(message))
        } catch {
            submission = .idle
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: Constants.featureName,
                    action: isEditing ? "입출금 기록 수정" : "입출금 기록 추가",
                    retryAction: { [weak self] in await self?.save() }
                )
            )
        }
    }
}

fileprivate enum Constants {
    static let featureName = "포트폴리오"
    static let createTitle = "입출금 기록"
    static let editTitle = "입출금 기록 수정"
}
