//
//  AlertPrompt.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation

/// 확인/취소 다이얼로그 모델. 파괴적 작업(종목·일지 삭제)과 되돌릴 수 없는 분기점에만 쓴다.
public struct AlertPrompt: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String?
    public let confirmTitle: String
    public let cancelTitle: String
    public let isDestructive: Bool
    public let confirmAction: @MainActor @Sendable () -> Void

    public init(
        title: String,
        message: String? = nil,
        confirmTitle: String,
        cancelTitle: String = "취소",
        isDestructive: Bool = false,
        confirmAction: @escaping @MainActor @Sendable () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.confirmAction = confirmAction
    }
}
