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
/// 저빈도인 벤치마크 고르기는 액세서리가 아니라 툴바 아이콘이 연다. 캡슐에 칩을 늘어놓던
/// 자리를 시트로 옮긴 덕에 지수가 늘어도 폭 걱정이 없고, 조회에 실패한 지수는 왜 못 고르는지
/// 까지 적을 수 있다 — 칩에서는 흐릿하게 비활성으로 보일 뿐 이유를 말할 자리가 없었다.
///
/// 고른 지수를 다시 누르면 선택이 풀린다. 비교 on/off 는 상단 "차트에 겹치기" 스위치가
/// 맡는다 — 지수를 고른 뒤에도 스위치를 만질 수 있어야 하므로 행을 골라도 시트를 닫지
/// 않는다. 닫는 일은 완료 버튼의 몫이다.
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
                    overlayToggleRow
                }

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

    /// 켜짐/꺼짐은 `viewModel.toggleBenchmarkOverlay()` 를 그대로 부른다 —
    /// `private(set)` 인 `isBenchmarkOverlayEnabled` 를 바인딩으로 직접 뚫지 않고, "고른
    /// 지수가 없으면 켜지지 않는다"는 규칙을 ViewModel 한 곳에만 둔다.
    private var overlayBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isBenchmarkOverlayEnabled },
            set: { _ in viewModel.toggleBenchmarkOverlay() }
        )
    }

    /// 고를 지수가 없으면 겹칠 대상도 없으므로 스위치를 비활성으로 내리고 이유를 적는다.
    private var overlayToggleRow: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Toggle(Constants.overlayToggleTitle, isOn: overlayBinding)
                .disabled(viewModel.selectedBenchmark == nil)

            if viewModel.selectedBenchmark == nil {
                Text(Constants.overlayDisabledMessage)
                    .hannunFont(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .listRowBackground(Color.surfacePrimary)
    }

    /// 하나도 못 고르는 상태에서 "다시 누르면 해제됩니다"를 띄우면 고를 수 있다는 뜻으로
    /// 읽힌다 — 그럴 때는 왜 아무것도 못 고르는지를 말한다.
    private var footerMessage: String {
        BenchmarkIndex.allCases.contains(where: viewModel.isBenchmarkAvailable)
            ? Constants.footerMessage
            : Constants.allUnavailableMessage
    }

    /// 골라도 시트를 닫지 않는다 — 위 스위치를 이어서 만질 수 있어야 한다. 닫는 일은
    /// 완료 버튼의 몫이다.
    private func row(for index: BenchmarkIndex) -> some View {
        let isAvailable = viewModel.isBenchmarkAvailable(index)
        let isSelected = viewModel.selectedBenchmark == index

        return Button {
            viewModel.toggleBenchmark(index)
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
    static let overlayToggleTitle = "차트에 겹치기"
    static let overlayDisabledMessage = "먼저 비교할 지수를 고르세요"
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

#Preview("벤치마크 선택 · 미선택(스위치 비활성)") {
    BenchmarkPickerSheet(viewModel: .previewWithoutBenchmark)
}

#Preview("벤치마크 선택 · 선택 O, 겹치기 OFF") {
    BenchmarkPickerSheet(viewModel: .previewWithOverlayOff)
}
#endif
