//
//  HoldingEditorView.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 종목 추가·수정 sheet (PF-2, PF-3).
///
/// 추가는 자산유형 → 종목 정보 → 보유 정보 세 단계로 나눈다. 수정은 마지막 단계만 연다 —
/// 자산유형이나 티커가 달라지면 그건 같은 종목이 아니다.
struct HoldingEditorView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: HoldingEditorViewModel

    private let onSaved: () -> Void

    // MARK: - Body

    @MainActor
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        mode: HoldingEditorMode,
        onSaved: @escaping () -> Void
    ) {
        self.onSaved = onSaved
        _viewModel = State(
            initialValue: HoldingEditorViewModel(
                saveHolding: container.resolve((any SaveHoldingUseCaseProtocol).self),
                errorHandler: errorHandler,
                mode: mode
            )
        )
    }

    var body: some View {
        VStack(spacing: .spacingL) {
            Text(viewModel.title)
                .hannunFont(.rowTitle)
                .foregroundStyle(Color.textPrimary)

            ScrollView {
                stepContent
                    .padding(.horizontal, .spacingL)
                    .padding(.bottom, .spacingL)
            }
            .scrollBounceBehavior(.basedOnSize)

            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.loss)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .spacingL)
            }

            actions
        }
        .padding(.top, .spacingL)
        .padding(.bottom, .spacingL)
        .presentationDetents(viewModel.isEditing ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        .hannunAnimation(.sheet, value: viewModel.step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .assetType:
            assetTypeStep
        case .identity:
            identityStep
        case .position:
            positionStep
        }
    }

    private var assetTypeStep: some View {
        VStack(spacing: .spacingXS) {
            ForEach(AssetCategory.allCases, id: \.self) { category in
                categoryOption(category)
            }
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            FormField(Constants.nameTitle) {
                TextField(namePlaceholder, text: $viewModel.name)
                    .hannunFont(.rowTitle)
                    .foregroundStyle(Color.textPrimary)
            }

            if !viewModel.isCash {
                FormField(Constants.tickerTitle) {
                    TextField(Constants.tickerPlaceholder, text: $viewModel.ticker)
                        .hannunFont(.rowTitle)
                        .foregroundStyle(Color.textPrimary)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }

            currencyField
        }
    }

    private var positionStep: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            DecimalFormField(
                title: viewModel.quantityFieldTitle,
                placeholder: Constants.numberPlaceholder,
                unit: viewModel.quantityUnit,
                text: $viewModel.quantityText
            )

            if !viewModel.isCash {
                DecimalFormField(
                    title: Constants.averagePriceTitle,
                    placeholder: Constants.numberPlaceholder,
                    unit: viewModel.currency.rawValue,
                    text: $viewModel.averagePriceText
                )

                manualPriceField
            }
        }
    }

    /// 시세를 못 가져오는 종목의 폴백. 켜면 입력한 값이 평가금액의 기준이 된다 (PF-2).
    private var manualPriceField: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            Toggle(Constants.manualPriceTitle, isOn: $viewModel.usesManualPrice)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.brand)

            if viewModel.usesManualPrice {
                DecimalFormField(
                    title: Constants.currentPriceTitle,
                    placeholder: Constants.numberPlaceholder,
                    unit: viewModel.currency.rawValue,
                    text: $viewModel.manualPriceText
                )
            } else {
                Text(Constants.manualPriceHint)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var currencyField: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(Constants.currencyTitle)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            CurrencyToggle(selection: $viewModel.currency)
        }
    }

    private var actions: some View {
        HStack(spacing: .spacingM) {
            Button(secondaryTitle) {
                if viewModel.canGoBack {
                    viewModel.retreat()
                } else {
                    dismiss()
                }
            }
            .frame(maxWidth: .infinity)
            .hannunButtonStyle(.sheetSecondary)

            Button(primaryTitle) {
                guard viewModel.isLastStep else {
                    viewModel.advance()
                    return
                }
                Task { await submit() }
            }
            .frame(maxWidth: .infinity)
            .hannunButtonStyle(.sheetPrimary)
            .tint(Color.brand)
            .disabled(!viewModel.canProceed || viewModel.isSaving)
        }
        .hannunFont(.rowTitle)
        .controlSize(.large)
        .padding(.horizontal, .spacingL)
    }

    private var secondaryTitle: String {
        viewModel.canGoBack ? Constants.backTitle : Constants.cancelTitle
    }

    private var primaryTitle: String {
        viewModel.isLastStep ? Constants.saveTitle : Constants.nextTitle
    }

    private var namePlaceholder: String {
        viewModel.isCash ? Constants.cashNamePlaceholder : Constants.namePlaceholder
    }

    // MARK: - Function

    private func categoryOption(_ category: AssetCategory) -> some View {
        let isSelected = viewModel.category == category

        return Button {
            viewModel.selectCategory(category)
        } label: {
            HStack(spacing: .spacingM) {
                CategoryDot(category)

                Text(category.title)
                    .hannunFont(.rowTitle)
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: .spacingS)

                if isSelected {
                    Image(systemName: Constants.checkmarkSymbolName)
                        .hannunFont(.subtext)
                        .foregroundStyle(Color.brand)
                }
            }
            .padding(.vertical, .spacingM)
            .padding(.horizontal, .spacingL)
            .contentShape(.rect)
            .background(
                isSelected ? Color.surfaceSecondary : Color.clear,
                in: .rect(cornerRadius: .radiusS)
            )
        }
        .buttonStyle(.plain)
    }

    private func submit() async {
        await viewModel.save()

        guard viewModel.didSave else { return }
        onSaved()
        dismiss()
    }
}

fileprivate enum Constants {
    static let nameTitle = "종목명"
    static let tickerTitle = "티커"
    static let currencyTitle = "통화"
    static let averagePriceTitle = "평단가"
    static let currentPriceTitle = "현재가"
    static let manualPriceTitle = "현재가 직접 입력"
    static let manualPriceHint = "시세를 가져오지 못하면 평단가를 현재가로 씁니다."
    static let namePlaceholder = "삼성전자"
    static let cashNamePlaceholder = "원화 예수금"
    static let tickerPlaceholder = "005930"
    static let numberPlaceholder = "0"
    static let cancelTitle = "취소"
    static let backTitle = "이전"
    static let nextTitle = "다음"
    static let saveTitle = "저장"
    static let checkmarkSymbolName = "checkmark"
}
