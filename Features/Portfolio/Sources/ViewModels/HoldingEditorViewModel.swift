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
    /// 시세 앱키가 들어와 있는지만 묻는다. 프리뷰·테스트에서는 `nil` 이라 묻지 않는다.
    private let credentials: (any MarketCredentialsServiceProtocol)?
    private let editingHolding: HoldingRecord?

    private(set) var step: HoldingEditorStep
    private(set) var submission: Loadable<HoldingRecord> = .idle

    /// 시세 앱키가 없어 주식·ETF 현재가를 받아올 수 없는 상태.
    ///
    /// 등록 자체는 막지 않는다 — 평단가 폴백과 수동 입력가가 그대로 살아 있어서 지금 넣어도
    /// 평가금액은 나온다. 폼 하단 안내 문구만 그 사정에 맞게 바뀐다.
    private(set) var isMarketKeyMissing = false

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

    /// 티커·평단가 칸을 통째로 접는 기준. 현금과 대출이 잔액 한 칸으로 끝난다.
    var isBalanceOnly: Bool { category.isBalanceOnly }

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
            !trimmedName.isEmpty && (isBalanceOnly || !trimmedTicker.isEmpty)
        case .position:
            quantity != nil && (isBalanceOnly || averagePrice != nil)
        }
    }

    var isSaving: Bool { submission.isLoading }

    var didSave: Bool { submission.value != nil }

    var validationMessage: String? { submission.error?.userMessage }

    /// 편집 중인 종목의 평가 기준 통화. 현금·대출은 이 통화로 잔액을 그대로 읽는다.
    var quantityFieldTitle: String {
        category.quantityFieldTitle
    }

    var quantityUnit: String? {
        isBalanceOnly ? currency.rawValue : category.quantityUnit
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
        mode: HoldingEditorMode,
        credentials: (any MarketCredentialsServiceProtocol)? = nil
    ) {
        self.saveHolding = saveHolding
        self.errorHandler = errorHandler
        self.credentials = credentials

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

    /// 시트가 열릴 때 한 번 묻는다. 폼을 채우는 동안 설정을 다녀올 길이 없으므로 다시 볼 일도 없다.
    func loadMarketKeyState() async {
        guard let credentials else { return }
        isMarketKeyMissing = !(await credentials.isConfigured())
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
            ticker: isBalanceOnly ? "" : trimmedTicker,
            currency: currency,
            quantity: quantity,
            averagePrice: isBalanceOnly ? nil : DecimalInput.value(from: averagePriceText),
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
