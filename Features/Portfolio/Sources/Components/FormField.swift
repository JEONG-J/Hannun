//
//  FormField.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import SwiftUI

/// sheet 폼의 입력 한 칸. 라벨은 위, 값은 불투명 면 안에 둔다.
///
/// glass 를 쓰지 않는다 — 시트 자체가 이미 재질 위에 떠 있어 입력 면까지 반투명하면
/// 커서와 자릿수가 배경에 묻힌다.
struct FormField<Content: View>: View {

    // MARK: - Property

    private let title: String
    private let content: Content

    // MARK: - Body

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .spacingM)
                .padding(.horizontal, .spacingL)
                .background(Color.surfaceSecondary, in: .rect(cornerRadius: .radiusS))
        }
    }
}

/// 숫자 입력 칸. 단위를 오른쪽 끝에 붙여 무엇을 세는 값인지 보이게 한다.
struct DecimalFormField: View {

    // MARK: - Property

    let title: String
    let placeholder: String
    let unit: String?
    @Binding var text: String

    // MARK: - Body

    var body: some View {
        FormField(title) {
            HStack(spacing: .spacingS) {
                TextField(placeholder, text: $text)
                    .hannunFont(.rowAmount)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardType(.decimalPad)

                if let unit {
                    Text(unit)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

#if DEBUG
private struct FormFieldPreview: View {

    // MARK: - Property

    @State private var name = ""
    @State private var quantity = "10"

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            FormField("종목명") {
                TextField("삼성전자", text: $name)
                    .hannunFont(.rowTitle)
            }

            DecimalFormField(
                title: "수량",
                placeholder: "0",
                unit: "주",
                text: $quantity
            )
        }
        .padding(.spacingL)
        .background(Color.surfacePrimary)
    }
}

#Preview("폼 입력 칸") {
    FormFieldPreview()
}
#endif
