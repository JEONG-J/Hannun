//
//  SettingsViewModel.swift
//  SettingsFeature
//
//  Created by euijjang97 on 8/8/26.
//

import HannunCore
import HannunDomain
import Observation

/// 설정 화면의 상태. 지금 다루는 값은 시세 앱키 한 쌍뿐이다.
@MainActor
@Observable
public final class SettingsViewModel {
    // MARK: - Property

    private let credentials: any MarketCredentialsServiceProtocol

    var appKey = ""
    var appSecret = ""

    private(set) var isConfigured = false
    private(set) var submission: Loadable<Bool> = .idle

    /// 연결 해제 확인 다이얼로그. 지우면 다시 발급받아 붙여넣어야 하므로 한 번 물어본다.
    var removalPrompt: AlertPrompt?

    var isSaving: Bool { submission.isLoading }

    var errorMessage: String? { submission.error?.userMessage }

    /// 저장 버튼 활성 조건. 실제 형식 검증은 발급 요청이 대신한다 — 앱키 규격은 KIS 사정이라
    /// 앱이 길이나 문자 집합을 흉내 내면 규격이 바뀌는 날 멀쩡한 키를 막는다.
    var canSubmit: Bool {
        !isSaving && !appKey.isEmpty && !appSecret.isEmpty
    }

    // MARK: - Function

    public init(credentials: any MarketCredentialsServiceProtocol) {
        self.credentials = credentials
    }

    public func load() async {
        isConfigured = await credentials.isConfigured()
    }

    func save() async {
        submission = .loading

        do {
            try await credentials.save(appKey: appKey, appSecret: appSecret)
            isConfigured = true
            // 값 자체는 Keychain 이 갖는다. 화면에 남겨 둘 이유가 없다.
            appKey = ""
            appSecret = ""
            submission = .loaded(true)
        } catch {
            // 키가 틀렸다는 건 이 화면에서 고칠 수 있는 문제다. 전역 Alert 로 흐름을 끊지 않는다.
            submission = .failed(AppError(narrowing: error))
        }
    }

    func confirmRemoval() {
        removalPrompt = AlertPrompt(
            title: Constants.removalTitle,
            message: Constants.removalMessage,
            confirmTitle: Constants.removalConfirmTitle,
            isDestructive: true,
            confirmAction: { [weak self] in
                Task { await self?.remove() }
            }
        )
    }

    private func remove() async {
        await credentials.remove()
        isConfigured = false
        submission = .idle
    }
}

fileprivate enum Constants {
    static let removalTitle = "앱키를 지울까요?"
    static let removalMessage = "주식·ETF 시세와 환율 갱신이 멈춥니다. 코인 시세는 그대로 나옵니다."
    static let removalConfirmTitle = "지우기"
}
