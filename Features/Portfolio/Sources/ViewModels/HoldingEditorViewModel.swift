//
//  HoldingEditorViewModel.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import HannunDomain
import Observation

/// 종목 추가 sheet 의 단계. 한 화면에 폼 전체를 늘어놓지 않으려고 셋으로 쪼갠다.
enum HoldingEditorStep: Int, CaseIterable {
    case assetType = 1
    case identity
    case position

    var next: HoldingEditorStep? { HoldingEditorStep(rawValue: rawValue + 1) }
    var previous: HoldingEditorStep? { HoldingEditorStep(rawValue: rawValue - 1) }
}

/// 종목 추가·수정 sheet (PF-2, PF-3).
///
/// 수정은 수량과 평단가만 바꾼다 — 자산유형이나 티커가 달라지면 그건 다른 종목이다.
@MainActor
@Observable
final class HoldingEditorViewModel {

    // MARK: - Property

    private let saveHolding: any SaveHoldingUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let editingHolding: HoldingRecord?

    private(set) var step: HoldingEditorStep
    private(set) var submission: Loadable<HoldingRecord> = .idle

    var category: AssetCategory
    var name: String
    var ticker: String
    var currency: Currency
    var quantityText: String
    var averagePriceText: String
    var manualPriceText: String
    /// 시세가 없는 종목의 현재가 폴백. 켜면 입력한 값이 평가금액 기준이 된다.
    var usesManualPrice: Bool

    var isEditing: Bool { editingHolding != nil }

    var isCash: Bool { category == .cash }

    var title: String {
        guard !isEditing else { return Constants.editTitle }
        return "\(Constants.createTitle) (\(step.rawValue)/\(HoldingEditorStep.allCases.count))"
    }

    var isLastStep: Bool { step == .position }

    var canGoBack: Bool { !isEditing && step.previous != nil }

    /// 다음·저장 버튼 활성 조건. 저장 직전 UseCase 가 같은 규칙으로 다시 검증한다.
    var canProceed: Bool {
        switch step {
        case .assetType:
            true
        case .identity:
            !trimmedName.isEmpty && (isCash || !trimmedTicker.isEmpty)
        case .position:
            quantity != nil && (isCash || averagePrice != nil)
        }
    }

    var isSaving: Bool { submission.isLoading }

    var didSave: Bool { submission.value != nil }

    var validationMessage: String? { submission.error?.userMessage }

    /// 편집 중인 종목의 평가 기준 통화. 현금은 이 통화로 잔액을 그대로 읽는다.
    var quantityFieldTitle: String {
        AssetCategoryText.quantityFieldTitle(for: category)
    }

    var quantityUnit: String? {
        isCash ? currency.rawValue : AssetCategoryText.quantityUnit(for: category)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTicker: String {
        ticker.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var quantity: Decimal? {
        DecimalInput.value(from: quantityText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var averagePrice: Decimal? {
        DecimalInput.value(from: averagePriceText).flatMap { $0 > 0 ? $0 : nil }
    }

    // MARK: - Function

    init(
        saveHolding: any SaveHoldingUseCaseProtocol,
        errorHandler: ErrorHandler,
        mode: HoldingEditorMode
    ) {
        self.saveHolding = saveHolding
        self.errorHandler = errorHandler

        let holding = mode.editingHolding
        editingHolding = holding

        step = holding == nil ? .assetType : .position
        category = holding?.category ?? Constants.defaultCategory
        name = holding?.name ?? ""
        ticker = holding?.ticker ?? ""
        currency = holding?.currency ?? .krw
        quantityText = DecimalInput.text(from: holding?.quantity)
        averagePriceText = DecimalInput.text(from: holding?.averagePrice)
        manualPriceText = DecimalInput.text(from: holding?.manualPrice)
        usesManualPrice = holding?.manualPrice != nil
    }

    func advance() {
        guard canProceed, let next = step.next else { return }
        step = next
    }

    func retreat() {
        guard canGoBack, let previous = step.previous else { return }
        step = previous
    }

    func selectCategory(_ category: AssetCategory) {
        self.category = category
    }

    func save() async {
        guard let record = makeRecord() else { return }

        submission = .loading

        do {
            try await saveHolding.execute(record)
            submission = .loaded(record)
        } catch AppError.validation(let message) {
            // 입력 문제는 sheet 안에서 고칠 수 있으므로 전역 Alert 로 흐름을 끊지 않는다.
            submission = .failed(.validation(message))
        } catch {
            submission = .idle
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: Constants.featureName,
                    action: isEditing ? "종목 수정" : "종목 추가",
                    retryAction: { [weak self] in await self?.save() }
                )
            )
        }
    }

    private func makeRecord() -> HoldingRecord? {
        guard let quantity = DecimalInput.value(from: quantityText) else { return nil }

        return HoldingRecord(
            id: editingHolding?.id ?? UUID(),
            category: category,
            name: trimmedName,
            ticker: isCash ? "" : trimmedTicker,
            currency: currency,
            quantity: quantity,
            averagePrice: isCash ? nil : DecimalInput.value(from: averagePriceText),
            manualPrice: usesManualPrice ? DecimalInput.value(from: manualPriceText) : nil,
            createdAt: editingHolding?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

fileprivate enum Constants {
    static let featureName = "포트폴리오"
    static let createTitle = "종목 추가"
    static let editTitle = "보유 내역 수정"
    static let defaultCategory: AssetCategory = .domesticStock
}
