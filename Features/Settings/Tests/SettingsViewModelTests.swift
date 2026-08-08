//
//  SettingsViewModelTests.swift
//  SettingsFeatureTests
//
//  Created by euijjang97 on 8/8/26.
//

import HannunCore
import HannunDomain
import Testing

@testable import SettingsFeature

@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {

    // MARK: - 저장

    @Test("저장에 성공하면 입력 칸을 비우고 연결됨으로 바꾼다")
    func successfulSaveClearsFields() async {
        let service = StubCredentialsService()
        let viewModel = SettingsViewModel(credentials: service)
        viewModel.appKey = "PS-key"
        viewModel.appSecret = "secret"

        await viewModel.save()

        #expect(viewModel.isConfigured)
        #expect(viewModel.appKey.isEmpty)
        #expect(viewModel.appSecret.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(await service.saved?.appKey == "PS-key")
    }

    /// 실패한 키는 지우지 않는다 — 오타 한 글자 때문에 40자를 다시 붙여넣게 만들면 안 된다.
    @Test("저장에 실패하면 입력을 남긴 채 화면 안에서 사유를 말한다")
    func failedSaveKeepsInput() async {
        let service = StubCredentialsService(saveError: .unavailable("앱키를 확인해 주세요."))
        let viewModel = SettingsViewModel(credentials: service)
        viewModel.appKey = "wrong"
        viewModel.appSecret = "secret"

        await viewModel.save()

        #expect(!viewModel.isConfigured)
        #expect(viewModel.appKey == "wrong")
        #expect(viewModel.errorMessage == "앱키를 확인해 주세요.")
    }

    // MARK: - 삭제

    @Test("연결 해제는 확인을 거쳐야 실제로 지운다")
    func removalRequiresConfirmation() async throws {
        let service = StubCredentialsService()
        let viewModel = SettingsViewModel(credentials: service)
        viewModel.appKey = "PS-key"
        viewModel.appSecret = "secret"
        await viewModel.save()

        viewModel.confirmRemoval()

        let prompt = try #require(viewModel.removalPrompt)
        #expect(prompt.isDestructive)
        // 다이얼로그를 띄우기만 한 시점에는 아직 아무것도 지우지 않는다.
        #expect(await service.didRemove == false)

        prompt.confirmAction()

        #expect(await waitForRemoval(service))
        #expect(!viewModel.isConfigured)
    }
}

/// `confirmAction` 이 삭제를 `Task` 로 넘기므로 끝날 때까지 양보한다.
/// 영영 안 오는 경우 테스트가 매달리지 않도록 횟수를 막아 둔다.
private func waitForRemoval(_ service: StubCredentialsService) async -> Bool {
    for _ in 0..<20 {
        if await service.didRemove { return true }
        await Task.yield()
    }
    return false
}

// MARK: - Stub

private actor StubCredentialsService: MarketCredentialsServiceProtocol {
    private(set) var saved: (appKey: String, appSecret: String)?
    private(set) var didRemove = false

    private let saveError: AppError?

    init(saveError: AppError? = nil) {
        self.saveError = saveError
    }

    func isConfigured() async -> Bool { saved != nil }

    func save(appKey: String, appSecret: String) async throws {
        if let saveError { throw saveError }
        saved = (appKey, appSecret)
    }

    func remove() async {
        saved = nil
        didRemove = true
    }
}
