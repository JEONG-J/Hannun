//
//  BenchmarkAccessory.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 8/1/26.
//

import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 성과 탭 하단 액세서리 — 비교 벤치마크 전환 (PM-4, UI 스펙 §3.1).
///
/// 안쪽에 glass 를 다시 얹지 않는다. 캡슐이 이미 반투명이라 `ChipGroup(appearance: .accessory)`
/// 가 불투명 fill 로 그린다.
struct BenchmarkAccessory: View {

    // MARK: - Property

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private let viewModel: PerformanceViewModel

    // MARK: - Body

    init(viewModel: PerformanceViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BottomAccessory {
            if collapsesToMenu {
                collapsedMenu
            } else {
                chips
            }
        }
    }

    // MARK: - Function

    /// 탭바가 최소화됐거나 칩이 캡슐 폭(약 358pt)에 다 들어가지 않으면 Menu 로 접는다.
    private var collapsesToMenu: Bool {
        placement == .inline || BenchmarkIndex.allCases.count > Constants.maximumChipCount
    }

    private var chips: some View {
        ChipGroup(appearance: .accessory, scrollsHorizontally: false) {
            ForEach(BenchmarkIndex.allCases, id: \.self) { index in
                FilterChip(
                    index.title,
                    isSelected: viewModel.selectedBenchmark == index,
                    isEnabled: viewModel.isBenchmarkAvailable(index),
                    tint: index.lineColor
                ) {
                    viewModel.toggleBenchmark(index)
                }
            }
        }
    }

    private var collapsedMenu: some View {
        Menu {
            ForEach(BenchmarkIndex.allCases, id: \.self) { index in
                Button {
                    viewModel.toggleBenchmark(index)
                } label: {
                    menuItemLabel(for: index)
                }
                .disabled(!viewModel.isBenchmarkAvailable(index))
            }
        } label: {
            menuLabel
        }
        .accessibilityLabel(Constants.accessibilityLabel)
    }

    @ViewBuilder
    private func menuItemLabel(for index: BenchmarkIndex) -> some View {
        if index == viewModel.selectedBenchmark {
            Label(index.title, systemImage: Constants.selectionSymbolName)
        } else {
            Text(index.title)
        }
    }

    private var menuLabel: some View {
        HStack(spacing: .spacingXS) {
            Text(viewModel.selectedBenchmark?.title ?? Constants.emptySelectionTitle)
                .hannunFont(.pillLabel)
                .lineLimit(1)

            Image(systemName: Constants.chevronSymbolName)
                .imageScale(.small)
        }
        .foregroundStyle(menuLabelColor)
        .padding(.horizontal, Constants.labelHorizontalPadding)
        .frame(minHeight: .minimumTouchTarget)
        .background(menuLabelBackground, in: .capsule)
    }

    private var menuLabelBackground: AnyShapeStyle {
        guard let color = viewModel.selectedBenchmark?.lineColor else {
            return AnyShapeStyle(Color.surfaceSecondary)
        }
        return AnyShapeStyle(color)
    }

    private var menuLabelColor: Color {
        viewModel.selectedBenchmark == nil ? .textSecondary : .onBrand
    }
}

fileprivate enum Constants {
    /// 캡슐 안쪽 가용 폭이 약 358pt 라 짧은 칩 4개가 한계다 (UI 스펙 §3.1).
    static let maximumChipCount = 4
    static let labelHorizontalPadding: CGFloat = 14
    static let chevronSymbolName = "chevron.down"
    static let selectionSymbolName = "checkmark"
    static let emptySelectionTitle = "벤치마크"
    static let accessibilityLabel = "비교 벤치마크 선택"
}

#if DEBUG
#Preview("벤치마크 액세서리 · 라이트") {
    BenchmarkAccessory(viewModel: .preview)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("벤치마크 액세서리 · 다크") {
    BenchmarkAccessory(viewModel: .preview)
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
}
#endif
