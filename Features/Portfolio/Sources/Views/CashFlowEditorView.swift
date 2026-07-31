//
//  CashFlowEditorView.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 입출금 기록 추가·수정 sheet (PF-5, PF-6).
struct CashFlowEditorView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CashFlowEditorViewModel

    private let onSaved: () -> Void

    // MARK: - Body

    @MainActor
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        mode: CashFlowEditorMode,
        onSaved: @escaping () -> Void
    ) {
        self.onSaved = onSaved
        _viewModel = State(
            initialValue: CashFlowEditorViewModel(
                manageCashFlow: container.resolve((any ManageCashFlowUseCaseProtocol).self),
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
                fields
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
        .padding(.vertical, .spacingL)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            kindField

            DecimalFormField(
                title: Constants.amountTitle,
                placeholder: Constants.numberPlaceholder,
                unit: viewModel.currency.rawValue,
                text: $viewModel.amountText
            )

            currencyField
            dateField

            FormField(Constants.memoTitle) {
                TextField(Constants.memoPlaceholder, text: $viewModel.memo)
                    .hannunFont(.rowTitle)
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }

    private var kindField: some View {
        labeled(Constants.kindTitle) {
            ChipGroup(appearance: .accessory, scrollsHorizontally: false) {
                ForEach(CashFlowKind.allCases, id: \.self) { kind in
                    FilterChip(
                        CashFlowKindText.title(for: kind),
                        isSelected: viewModel.kind == kind
                    ) {
                        viewModel.kind = kind
                    }
                }
            }
        }
    }

    private var currencyField: some View {
        labeled(Constants.currencyTitle) {
            CurrencyToggle(selection: $viewModel.currency)
        }
    }

    private var dateField: some View {
        labeled(Constants.dateTitle) {
            DatePicker(
                Constants.dateTitle,
                selection: $viewModel.occurredOn,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Color.brand)
        }
    }

    private var actions: some View {
        HStack(spacing: .spacingM) {
            Button(Constants.cancelTitle) { dismiss() }
                .frame(maxWidth: .infinity)
                .hannunButtonStyle(.sheetSecondary)

            Button(Constants.saveTitle) {
                Task { await submit() }
            }
            .frame(maxWidth: .infinity)
            .hannunButtonStyle(.sheetPrimary)
            .tint(Color.brand)
            .disabled(!viewModel.canSave || viewModel.isSaving)
        }
        .hannunFont(.rowTitle)
        .controlSize(.large)
        .padding(.horizontal, .spacingL)
    }

    // MARK: - Function

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            content()
        }
    }

    private func submit() async {
        await viewModel.save()

        guard viewModel.didSave else { return }
        onSaved()
        dismiss()
    }
}

fileprivate enum Constants {
    static let kindTitle = "유형"
    static let amountTitle = "금액"
    static let currencyTitle = "통화"
    static let dateTitle = "날짜"
    static let memoTitle = "메모"
    static let memoPlaceholder = "월급 이체"
    static let numberPlaceholder = "0"
    static let cancelTitle = "취소"
    static let saveTitle = "저장"
}
