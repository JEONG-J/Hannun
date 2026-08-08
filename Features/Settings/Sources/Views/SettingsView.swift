//
//  SettingsView.swift
//  SettingsFeature
//
//  Created by euijjang97 on 8/8/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 설정 sheet. 시세 앱키를 넣고 지우는 자리다.
///
/// 앱은 시세 앱키를 바이너리에 담지 않고 사용자가 자기 것을 넣어 쓴다. 그래서 이 화면이 없는
/// 동안에는 주식·ETF 시세가 비는데, **앱을 못 쓰게 막지는 않는다** — 코인 시세와 현재가 수동
/// 입력은 키 없이도 돌고, 키가 필요한 자리마다 여기로 오는 길이 놓여 있다.
public struct SettingsView: View {
    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel: SettingsViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case appKey
        case appSecret
    }

    // MARK: - Body

    @MainActor
    public init(container: DIContainer) {
        _viewModel = State(
            initialValue: SettingsViewModel(
                credentials: container.resolve((any MarketCredentialsServiceProtocol).self)
            )
        )
    }

    public var body: some View {
        NavigationStack {
            Form {
                keySection
                guideSection

                if viewModel.isConfigured {
                    removalSection
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .alertPrompt(item: $viewModel.removalPrompt)
        .task { await viewModel.load() }
    }

    private var keySection: some View {
        Section {
            SecureField(Constants.appKeyPlaceholder, text: $viewModel.appKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .appKey)

            SecureField(Constants.appSecretPlaceholder, text: $viewModel.appSecret)
                .textContentType(.password)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .appSecret)
        } header: {
            sectionHeader(Constants.keySectionTitle)
        } footer: {
            keyFooter
        }
        .hannunFont(.body)
        .foregroundStyle(Color.textPrimary)
        .listRowBackground(Color.surfacePrimary)
    }

    /// 상태 한 줄과 실패 사유가 한 자리를 쓴다. 방금 저장에 실패했다면 그게 먼저다 —
    /// "연결됨" 과 실패 문구가 같이 뜨면 지금 어느 쪽인지 읽히지 않는다.
    @ViewBuilder
    private var keyFooter: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .hannunFont(.caption)
                .foregroundStyle(Color.loss)
        } else if viewModel.isConfigured {
            Label(Constants.configuredMessage, systemImage: Constants.configuredSymbolName)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
        } else {
            Text(Constants.unconfiguredMessage)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var guideSection: some View {
        Section {
            Button {
                openURL(Constants.issuingURL)
            } label: {
                HStack(spacing: .spacingM) {
                    Text(Constants.issuingLinkTitle)
                        .hannunFont(.body)
                        .foregroundStyle(Color.brand)

                    Spacer(minLength: .spacingS)

                    Image(systemName: Constants.externalLinkSymbolName)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } header: {
            sectionHeader(Constants.guideSectionTitle)
        } footer: {
            Text(Constants.guideMessage)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    private var removalSection: some View {
        Section {
            Button(Constants.removalTitle, role: .destructive) {
                focusedField = nil
                viewModel.confirmRemoval()
            }
            .hannunFont(.body)
            .disabled(viewModel.isSaving)
        }
        .listRowBackground(Color.surfacePrimary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Constants.closeTitle) { dismiss() }
                .disabled(viewModel.isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(Constants.saveTitle) {
                focusedField = nil
                Task { await viewModel.save() }
            }
            .hannunButtonStyle(.sheetPrimary)
            .tint(Color.brand)
            .disabled(!viewModel.canSubmit)
        }
    }

    // MARK: - Function

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .hannunFont(.caption)
            .foregroundStyle(Color.textSecondary)
            .textCase(nil)
    }
}

fileprivate enum Constants {
    static let title = "설정"
    static let keySectionTitle = "시세 앱키"
    static let guideSectionTitle = "앱키 발급"
    static let appKeyPlaceholder = "앱키"
    static let appSecretPlaceholder = "앱시크릿"
    static let configuredMessage = "연결됨"
    static let unconfiguredMessage = "넣지 않아도 앱은 그대로 쓸 수 있어요. 코인 시세와 현재가 "
        + "직접 입력은 앱키 없이 동작합니다."
    static let guideMessage = "한국투자증권 계좌를 만들고 개발자센터에서 앱키를 발급받으면 "
        + "주식·ETF 시세와 원/달러 환율이 자동으로 채워집니다. 발급받은 키는 이 기기의 "
        + "Keychain 에만 저장되고 다른 곳으로 나가지 않습니다."
    static let issuingLinkTitle = "한국투자증권 개발자센터 열기"
    static let removalTitle = "앱키 지우기"
    static let closeTitle = "닫기"
    static let saveTitle = "저장"
    static let configuredSymbolName = "checkmark.circle.fill"
    static let externalLinkSymbolName = "arrow.up.right.square"

    /// 앱키 발급 창구. 도메인이 바뀌면 여기만 고친다.
    static let issuingURL = URL(string: "https://apiportal.koreainvestment.com/")!
}

#if DEBUG
/// 프리뷰는 폼 레이아웃만 본다 — 저장은 성공한 셈 친다.
private struct StubCredentialsService: MarketCredentialsServiceProtocol {
    let configured: Bool

    func isConfigured() async -> Bool { configured }
    func save(appKey: String, appSecret: String) async throws {}
    func remove() async {}
}

@MainActor
private func previewSettings(configured: Bool) -> some View {
    let container = DIContainer()
    container.register((any MarketCredentialsServiceProtocol).self) {
        StubCredentialsService(configured: configured)
    }

    return SettingsView(container: container)
}

/// 아직 키가 없는 상태. 안내 문구가 "앱키 없이도 쓸 수 있다" 는 쪽을 먼저 말하는지 본다.
#Preview("설정 · 미설정") {
    previewSettings(configured: false)
}

/// 키가 들어간 상태. "연결됨" 과 지우기 줄이 함께 나온다.
#Preview("설정 · 연결됨") {
    previewSettings(configured: true)
}

/// 최대 글자 크기. 안내 문단이 길어져도 입력 칸을 밀어내지 않아야 한다.
#Preview("설정 · AX5") {
    previewSettings(configured: false)
        .dynamicTypeSize(.accessibility5)
}
#endif
