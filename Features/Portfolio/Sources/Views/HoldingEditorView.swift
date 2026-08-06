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
///
/// 단계마다 `Form` 섹션 하나를 걸고, 다음·이전은 내비게이션 바에 둔다. 입출금 시트와 같은
/// 문법이다 — 두 시트가 같은 탭에서 번갈아 열리므로 값을 적는 방식이 서로 달라선 안 된다.
/// 바에 두면 단계가 넘어갈 때 아래에서 버튼이 다시 그려지지 않아 어디를 눌러야 하는지가
/// 세 단계 내내 같은 자리에 남는다.
struct HoldingEditorView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: HoldingEditorViewModel
    @FocusState private var focusedField: Field?

    private let onSaved: () -> Void

    private enum Field {
        case name
        case ticker
        case quantity
        case averagePrice
        case manualPrice
    }

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
        NavigationStack {
            Form {
                stepContent
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
        // 어느 단계든 행이 다섯을 넘지 않는다. 전체 높이로 열면 아래 절반이 빈 채로 뒤 화면만
        // 가리므로 절반에서 시작하고, 끌어 올리거나 키보드가 올라오면 그때 커진다.
        .presentationDetents([.medium, .large])
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
        Section {
            ForEach(AssetCategory.allCases, id: \.self) { category in
                categoryRow(category)
            }
        } header: {
            sectionHeader(Constants.assetTypeTitle)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    private var identityStep: some View {
        Section {
            row(Constants.nameTitle) {
                TextField(namePlaceholder, text: $viewModel.name)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .name)
            }

            if !viewModel.isCash {
                row(Constants.tickerTitle) {
                    TextField(Constants.tickerPlaceholder, text: $viewModel.ticker)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .ticker)
                }
            }

            // 이 단계에는 금액이 없어 통화가 무엇의 단위인지 붙일 자리가 없다. 그래서 입출금
            // 폼처럼 숫자 옆 메뉴로 접지 않고, 값 둘을 그대로 펼친 칩으로 한 번에 고르게 둔다.
            row(Constants.currencyTitle) {
                CurrencyToggle(selection: $viewModel.currency)
            }
        } header: {
            sectionHeader(Constants.identityTitle)
        } footer: {
            validationFooter
        }
        .listRowBackground(Color.surfacePrimary)
    }

    private var positionStep: some View {
        Section {
            decimalRow(
                viewModel.quantityFieldTitle,
                unit: viewModel.quantityUnit,
                text: $viewModel.quantityText,
                field: .quantity
            )

            if !viewModel.isCash {
                decimalRow(
                    Constants.averagePriceTitle,
                    unit: viewModel.currency.rawValue,
                    text: $viewModel.averagePriceText,
                    field: .averagePrice
                )

                // 시세를 못 가져오는 종목의 폴백. 켜면 입력한 값이 평가금액의 기준이 된다 (PF-2).
                Toggle(Constants.manualPriceTitle, isOn: $viewModel.usesManualPrice)
                    .hannunFont(.body)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.brand)

                if viewModel.usesManualPrice {
                    decimalRow(
                        Constants.currentPriceTitle,
                        unit: viewModel.currency.rawValue,
                        text: $viewModel.manualPriceText,
                        field: .manualPrice
                    )
                }
            }
        } header: {
            sectionHeader(Constants.positionTitle)
        } footer: {
            positionFooter
        }
        .listRowBackground(Color.surfacePrimary)
    }

    @ViewBuilder
    private var validationFooter: some View {
        if let validationMessage = viewModel.validationMessage {
            Text(validationMessage)
                .hannunFont(.caption)
                .foregroundStyle(Color.loss)
        }
    }

    /// 검증 문구와 폴백 안내가 한 자리를 쓴다. 안내는 토글이 꺼져 있을 때만 — 켜면 바로 아래
    /// 현재가 칸이 답을 대신한다.
    private var positionFooter: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            validationFooter

            if !viewModel.isCash && !viewModel.usesManualPrice {
                Text(Constants.manualPriceHint)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(secondaryTitle) {
                focusedField = nil

                if viewModel.canGoBack {
                    viewModel.retreat()
                } else {
                    dismiss()
                }
            }
            .disabled(viewModel.isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(primaryTitle) {
                focusedField = nil

                guard viewModel.isLastStep else {
                    viewModel.advance()
                    return
                }
                Task { await submit() }
            }
            .hannunButtonStyle(.sheetPrimary)
            .tint(Color.brand)
            .disabled(!viewModel.canProceed || viewModel.isSaving)
        }

        // 수량·평단가는 `.decimalPad` 라 리턴 키가 없다 — 닫는 자리를 만들어 둔다.
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()

            Button(Constants.doneTitle) { focusedField = nil }
        }
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

    private func categoryRow(_ category: AssetCategory) -> some View {
        Button {
            viewModel.selectCategory(category)
        } label: {
            HStack(spacing: .spacingM) {
                CategoryDot(category)

                Text(category.title)
                    .hannunFont(.body)
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: .spacingS)

                if viewModel.category == category {
                    Image(systemName: Constants.checkmarkSymbolName)
                        .hannunFont(.subtext)
                        .foregroundStyle(Color.brand)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func decimalRow(
        _ title: String,
        unit: String?,
        text: Binding<String>,
        field: Field
    ) -> some View {
        row(title) {
            HStack(spacing: .spacingS) {
                TextField(Constants.numberPlaceholder, text: text)
                    .hannunFont(.rowAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: field)

                if let unit {
                    Text(unit)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: .spacingM) {
            Text(title)
                .hannunFont(.body)
                .foregroundStyle(Color.textPrimary)

            content()
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(nil)
    }

    private func submit() async {
        await viewModel.save()

        guard viewModel.didSave else { return }
        onSaved()
        dismiss()
    }
}

fileprivate enum Constants {
    static let assetTypeTitle = "자산유형"
    static let identityTitle = "종목 정보"
    static let positionTitle = "보유 정보"
    static let nameTitle = "종목명"
    /// 이 칸이 받는 값은 `KRW-BTC`·`005930`·`NAS:AAPL`·`AAPL` 넷이다. 국내 6자리를 "티커" 로만
    /// 부르면 무엇을 넣는 자리인지 읽히지 않아 국내·해외를 함께 적는다.
    static let tickerTitle = "티커·종목코드"
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
    static let doneTitle = "완료"
    static let checkmarkSymbolName = "checkmark"
}

#if DEBUG
/// 프리뷰는 폼 레이아웃만 본다 — 저장은 성공한 셈 친다.
private struct StubSaveHoldingUseCase: SaveHoldingUseCaseProtocol {
    func execute(_ holding: HoldingRecord) async throws {}
}

@MainActor
private func previewEditor() -> some View {
    let container = DIContainer()
    container.register((any SaveHoldingUseCaseProtocol).self) { StubSaveHoldingUseCase() }

    return HoldingEditorView(
        container: container,
        errorHandler: ErrorHandler(),
        mode: .create,
        onSaved: {}
    )
}

/// 자산유형을 고르고 `다음` 을 누르면 종목 정보 단계가 나온다 — "티커·종목코드" 라벨과 입력
/// 칸이 한 행에서 좌·우로 갈라지는지 본다.
#Preview("종목 추가 · 기본 글자") {
    previewEditor()
}

/// 같은 행을 최대 글자 크기로 본다. 라벨이 길어지면 여러 줄로 접힐 뿐 입력 칸을 밀어내지
/// 않아야 한다.
#Preview("종목 추가 · AX5") {
    previewEditor()
        .dynamicTypeSize(.accessibility5)
}
#endif
