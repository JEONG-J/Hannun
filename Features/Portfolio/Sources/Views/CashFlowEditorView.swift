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
///
/// 라벨을 값 위에 세우는 카드형 입력 칸 대신 `Form` 의 **라벨-값 한 줄** 문법을 쓴다. 이 화면이
/// 받는 값은 다섯인데 칸마다 두 줄씩 잡아먹으면 스크롤이 생기고, 스크롤이 생기는 순간 아래에
/// 깔아 둔 저장 버튼이 화면 밖으로 밀린다. 한 값 한 줄이면 다섯이 다 첫 화면에 들어온다.
///
/// 저장·취소는 시트 하단이 아니라 **내비게이션 바**에 둔다 — 일지 작성 시트가 이미 같은 자리를
/// 쓰고, 폼이 길어져도 두 액션이 늘 같은 곳에 남는다.
///
/// 검증 문구는 버튼 위가 아니라 **금액이 든 섹션의 footer** 다. 틀린 값 바로 아래에서 말해야
/// 무엇을 고쳐야 하는지가 문구를 읽기 전에 보인다.
struct CashFlowEditorView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CashFlowEditorViewModel
    @FocusState private var focusedField: Field?

    private let onSaved: () -> Void

    private enum Field {
        case amount
        case memo
    }

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
        NavigationStack {
            Form {
                Section {
                    kindRow
                    amountRow
                    dateRow
                } footer: {
                    validationFooter
                }
                .listRowBackground(Color.surfacePrimary)

                Section {
                    memoRow
                } header: {
                    Text(Constants.memoTitle)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .textCase(nil)
                }
                .listRowBackground(Color.surfacePrimary)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // safe area 를 넘겨 칠한다 — 키보드가 올라오면 폼 프레임이 그만큼 줄어드는데,
            // 배경이 프레임 안에만 있으면 키보드 툴바 자리에 시트의 흰 바탕이 드러난다.
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDetents([.large])
    }

    /// 입금·출금은 값 둘뿐이라 접지 않고 펼친 칩으로 둔다. 이 기록이 무엇인지가 폼을 여는
    /// 순간 보여야 아래 금액을 어떤 부호로 읽을지가 정해진다 — 메뉴로 접으면 그 답이 한 번
    /// 눌러야 나온다.
    private var kindRow: some View {
        row(Constants.kindTitle) {
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

    private var amountRow: some View {
        row(Constants.amountTitle) {
            HStack(spacing: .spacingS) {
                TextField(Constants.numberPlaceholder, text: $viewModel.amountText)
                    .hannunFont(.rowAmount)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .amount)

                currencyPicker
            }
        }
    }

    /// 통화는 독립된 값이 아니라 **방금 적는 숫자의 단위**라, 단위 자리를 그대로 컨트롤로
    /// 만든다 — 보고 있는 곳이 곧 누르는 곳이다.
    ///
    /// 행을 따로 떼면 자릿수를 세다 말고 아래로 눈을 옮겨야 하고, 무엇보다 키보드가 올라와
    /// 있는 동안 그 행이 가려져 "금액을 다 적고 나서야 통화를 고를 수 있는" 순서가 강요된다.
    /// 값 둘뿐이라 칩 두 개를 나란히 둘 수도 있지만, 그러면 이 행의 주인공인 숫자가 좁아진다.
    private var currencyPicker: some View {
        Picker(Constants.currencyTitle, selection: $viewModel.currency) {
            ForEach(Currency.allCases, id: \.self) { currency in
                Text(currency.rawValue).tag(currency)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .hannunFont(.pillLabel)
        .tint(Color.brand)
    }

    /// 라벨을 스스로 그리는 컨트롤이라 `row(_:content:)` 를 거치지 않는다.
    private var dateRow: some View {
        DatePicker(
            Constants.dateTitle,
            selection: $viewModel.occurredOn,
            displayedComponents: .date
        )
        .hannunFont(.body)
        .foregroundStyle(Color.textPrimary)
        .tint(Color.brand)
    }

    /// 메모만 섹션을 따로 쓴다. 값이 아니라 문장이라 한 줄에 가두면 적다가 잘리고, 라벨-값 행에
    /// 끼워 넣으면 오른쪽 좁은 칸에 여러 줄이 쌓인다.
    private var memoRow: some View {
        TextField(Constants.memoPlaceholder, text: $viewModel.memo, axis: .vertical)
            .hannunFont(.body)
            .foregroundStyle(Color.textPrimary)
            .lineLimit(Constants.memoLineLimit)
            .focused($focusedField, equals: .memo)
    }

    @ViewBuilder
    private var validationFooter: some View {
        if let validationMessage = viewModel.validationMessage {
            Text(validationMessage)
                .hannunFont(.caption)
                .foregroundStyle(Color.loss)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Constants.cancelTitle) { dismiss() }
                .disabled(viewModel.isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(Constants.saveTitle) {
                focusedField = nil
                Task { await submit() }
            }
            .hannunButtonStyle(.sheetPrimary)
            .tint(Color.brand)
            .disabled(!viewModel.canSave || viewModel.isSaving)
        }

        // 금액은 `.decimalPad` 라 리턴 키가 없고 메모는 줄바꿈을 먹는다 — 어느 쪽도 키보드를
        // 스스로 닫지 못하므로 닫는 자리를 만들어 둔다.
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()

            Button(Constants.doneTitle) { focusedField = nil }
        }
    }

    // MARK: - Function

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: .spacingM) {
            Text(title)
                .hannunFont(.body)
                .foregroundStyle(Color.textPrimary)

            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
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
    static let memoTitle = "메모 (선택)"
    static let memoPlaceholder = "월급 이체"
    static let memoLineLimit = 4
    static let numberPlaceholder = "0"
    static let cancelTitle = "취소"
    static let saveTitle = "저장"
    static let doneTitle = "완료"
}
