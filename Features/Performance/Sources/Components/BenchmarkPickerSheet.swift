//
//  BenchmarkPickerSheet.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 비교할 지수를 고르는 시트 (PM-4, 디자인 문서 §7).
///
/// 액세서리 왼쪽 한 줄을 눌러 연다. 캡슐에 칩을 늘어놓던 자리를 시트로 옮긴 덕에 지수가
/// 늘어도 폭 걱정이 없고, 조회에 실패한 지수는 왜 못 고르는지까지 적을 수 있다 — 칩에서는
/// 흐릿하게 비활성으로 보일 뿐 이유를 말할 자리가 없었다.
///
/// 고른 지수를 다시 누르면 선택이 풀린다. 비교를 아예 끄는 일은 캡슐 오른쪽 컨트롤이 맡으므로
/// 여기에 "비교 안 함" 행을 따로 두지 않는다.
struct BenchmarkPickerSheet: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BenchmarkIndex.allCases, id: \.self) { index in
                        row(for: index)
                    }
                } footer: {
                    Text(footerMessage)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimary)
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Constants.doneTitle) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Function

    /// 하나도 못 고르는 상태에서 "다시 누르면 해제됩니다"를 띄우면 고를 수 있다는 뜻으로
    /// 읽힌다 — 그럴 때는 왜 아무것도 못 고르는지를 말한다.
    private var footerMessage: String {
        BenchmarkIndex.allCases.contains(where: viewModel.isBenchmarkAvailable)
            ? Constants.footerMessage
            : Constants.allUnavailableMessage
    }

    private func row(for index: BenchmarkIndex) -> some View {
        let isAvailable = viewModel.isBenchmarkAvailable(index)
        let isSelected = viewModel.selectedBenchmark == index

        return Button {
            viewModel.toggleBenchmark(index)
            dismiss()
        } label: {
            HStack(spacing: .spacingM) {
                // 라벨만 흐려 두면 원색 닷이 그대로 남아 "고를 수 있는 행"으로 읽힌다.
                CategoryDot(color: index.lineColor)
                    .opacity(isAvailable ? 1 : Constants.unavailableDotOpacity)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text(index.title)
                        .hannunFont(.body)
                        .foregroundStyle(isAvailable ? Color.textPrimary : Color.textSecondary)

                    if !isAvailable {
                        Text(Constants.unavailableMessage)
                            .hannunFont(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer(minLength: .spacingS)

                if isSelected {
                    Image(systemName: Constants.selectionSymbolName)
                        .foregroundStyle(Color.brand)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: .minimumTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .listRowBackground(Color.surfacePrimary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

fileprivate enum Constants {
    static let title = "비교 벤치마크"
    static let doneTitle = "완료"
    static let selectionSymbolName = "checkmark"
    static let unavailableMessage = "지수를 불러오지 못했어요"
    static let footerMessage = "고른 지수를 다시 누르면 비교가 해제됩니다."
    static let allUnavailableMessage = "지수를 하나도 불러오지 못했어요. 잠시 뒤 성과 화면을 당겨 새로고침해 보세요."
    /// 라벨(`textSecondary`)이 배경과 남기는 대비와 눈으로 맞춘 값. 완전히 지우면 어느 지수
    /// 자리인지조차 사라진다.
    static let unavailableDotOpacity: Double = 0.35
}

#if DEBUG
#Preview("벤치마크 선택 · 라이트") {
    BenchmarkPickerSheet(viewModel: .preview)
        .preferredColorScheme(.light)
}

#Preview("벤치마크 선택 · 다크") {
    BenchmarkPickerSheet(viewModel: .preview)
        .preferredColorScheme(.dark)
}
#endif
