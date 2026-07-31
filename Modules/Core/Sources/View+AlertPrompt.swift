//
//  View+AlertPrompt.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

public extension View {
    /// 바인딩에 AlertPrompt 가 들어오면 확인/취소 다이얼로그를 띄운다.
    /// 확인·취소 어느 쪽이든 바인딩을 비워 같은 프롬프트가 다시 뜨지 않게 한다.
    func alertPrompt(item: Binding<AlertPrompt?>) -> some View {
        alert(
            Text(item.wrappedValue?.title ?? ""),
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented { item.wrappedValue = nil }
                }
            ),
            presenting: item.wrappedValue
        ) { prompt in
            let confirmRole: ButtonRole? = prompt.isDestructive ? .destructive : nil

            Button(prompt.cancelTitle, role: .cancel) {
                item.wrappedValue = nil
            }
            Button(prompt.confirmTitle, role: confirmRole) {
                prompt.confirmAction()
                item.wrappedValue = nil
            }
        } message: { prompt in
            if let message = prompt.message {
                Text(message)
            }
        }
    }
}
