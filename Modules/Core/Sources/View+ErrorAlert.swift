//
//  View+ErrorAlert.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

fileprivate enum Constants {
    static let errorAlertTitle: String = "문제가 발생했어요"
    static let retryActionTitle: String = "다시 시도"
    static let dismissActionTitle: String = "확인"
}

public extension View {
    /// ErrorHandler 가 담고 있는 흐름 중단형 에러를 Alert 으로 띄운다.
    /// 화면마다 붙이면 같은 에러로 Alert 이 여러 개 뜨므로 앱 루트에 한 번만 붙인다.
    func errorAlert(_ handler: ErrorHandler) -> some View {
        alert(
            Text(Constants.errorAlertTitle),
            isPresented: Binding(
                get: { handler.presentedError != nil },
                set: { isPresented in
                    if !isPresented { handler.dismiss() }
                }
            ),
            presenting: handler.presentedError
        ) { presented in
            if presented.canRetry {
                Button(Constants.retryActionTitle) {
                    Task { await handler.retry() }
                }
            }
            Button(Constants.dismissActionTitle, role: .cancel) {
                handler.dismiss()
            }
        } message: { presented in
            Text(presented.error.userMessage)
        }
    }
}
