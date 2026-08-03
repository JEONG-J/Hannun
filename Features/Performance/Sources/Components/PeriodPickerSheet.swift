//
//  PeriodPickerSheet.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunDesignSystem
import SwiftUI

/// 추이 차트가 그릴 기간을 고르는 시트 (PM-2, 디자인 문서 §7).
///
/// 액세서리 왼쪽 한 줄을 눌러 연다. `BenchmarkPickerSheet` 와 같은 문법을 쓴다 — 행 하나에
/// 기간과 그 구간이 뜻하는 바 한 줄, 고른 기간에는 체크 표시. 기간은 벤치마크보다 훨씬 자주
/// 만지는 값이라 액세서리에 늘 보이지만, 여섯 개 선택지를 캡슐 폭에 다 늘어놓을 자리는 없어
/// 고르는 일 자체는 시트로 넘긴다.
struct PeriodPickerSheet: View {

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
                    ForEach(ChartPeriod.allCases) { period in
                        row(for: period)
                    }
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

    private func row(for period: ChartPeriod) -> some View {
        let isSelected = viewModel.period == period

        return Button {
            Task {
                await viewModel.selectPeriod(period)
                dismiss()
            }
        } label: {
            HStack(spacing: .spacingM) {
                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text(period.title)
                        .hannunFont(.body)
                        .foregroundStyle(Color.textPrimary)

                    Text(description(for: period))
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
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
        .listRowBackground(Color.surfacePrimary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func description(for period: ChartPeriod) -> String {
        switch period {
        case .oneMonth: Constants.oneMonthDescription
        case .threeMonths: Constants.threeMonthsDescription
        case .sixMonths: Constants.sixMonthsDescription
        case .yearToDate: Constants.yearToDateDescription
        case .oneYear: Constants.oneYearDescription
        case .all: Constants.allDescription
        }
    }
}

fileprivate enum Constants {
    static let title = "기간 선택"
    static let doneTitle = "완료"
    static let selectionSymbolName = "checkmark"
    static let oneMonthDescription = "최근 1개월"
    static let threeMonthsDescription = "최근 3개월"
    static let sixMonthsDescription = "최근 6개월"
    static let yearToDateDescription = "올해 1월 1일부터"
    static let oneYearDescription = "최근 1년"
    static let allDescription = "전체 기간"
}

#if DEBUG
#Preview("기간 선택 · 라이트") {
    PeriodPickerSheet(viewModel: .preview)
        .preferredColorScheme(.light)
}

#Preview("기간 선택 · 다크") {
    PeriodPickerSheet(viewModel: .preview)
        .preferredColorScheme(.dark)
}
#endif
