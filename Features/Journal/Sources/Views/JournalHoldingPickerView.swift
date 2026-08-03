//
//  JournalHoldingPickerView.swift
//  JournalFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 연결 종목 선택 화면 (JR-2).
///
/// 작성 폼 안에 있던 가로 스크롤 칩 줄을 화면 하나로 옮긴 것이다. 세로로 읽어 내려가던 손이
/// 한 줄에서만 옆으로 밀어야 하는 것도 문제지만, 더 큰 문제는 섹션 폭에서 잘린 마지막 칩이
/// "여기서 끝" 인지 "더 있다" 인지 말해 주지 않는다는 점이다. 보유 종목 수는 사용자마다
/// 다르고 상한도 없어서 애초에 한 줄에 담길 보장이 없다.
///
/// 목록 행은 분류 아이콘 + 이름 + 선택 표식 세 자리로 고정한다. 칩은 이름 길이에 따라 폭이
/// 흔들리지만 행은 어디를 눌러도 같은 자리에서 같은 폭으로 반응한다.
///
/// 선택은 누르는 즉시 반영된다. 되돌리기 버튼 대신 "전체 해제" 만 두는 이유는, 작성 폼 자체가
/// 아직 저장 전이라 여기서 또 취소를 받으면 되돌리기가 두 겹으로 쌓이기 때문이다.
struct JournalHoldingPickerView: View {

    // MARK: - Property

    private let viewModel: JournalComposeViewModel
    private let holdings: [HoldingRecord]

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    init(viewModel: JournalComposeViewModel, holdings: [HoldingRecord]) {
        self.viewModel = viewModel
        self.holdings = holdings
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(holdings) { holding in
                        holdingRow(holding)
                    }
                }
                .listRowBackground(Color.surfacePrimary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimary)
            .navigationTitle(Constants.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Function

    /// 행 전체가 과녁이다 — 표식만 눌리게 두면 오른쪽 끝 작은 원을 겨눠야 한다.
    private func holdingRow(_ holding: HoldingRecord) -> some View {
        Button {
            viewModel.toggleHolding(holding.id)
        } label: {
            HStack(spacing: .spacingM) {
                categoryIcon(holding.category)

                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text(holding.name)
                        .hannunFont(.body)
                        .foregroundStyle(Color.textPrimary)

                    Text(holding.category.title)
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                selectionMark(isSelected: viewModel.isSelected(holding.id))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.isSelected(holding.id) ? .isSelected : [])
    }

    /// 참조한 일정 앱은 이 아이콘 원을 `.clear` 유리로 칠하지만, 여기는 폼 안이라 불투명이
    /// 규칙이다 (UI 스펙 §5). 같은 분류색을 `HannunTint.wash(_:)` 로 깔아 재질만 다르고
    /// 색은 일지 셀 태그와 하나로 이어지게 한다.
    private func categoryIcon(_ category: AssetCategory) -> some View {
        Image(systemName: category.systemImageName)
            .hannunFont(.body)
            .foregroundStyle(category.color)
            .frame(width: Constants.iconDiameter, height: Constants.iconDiameter)
            .background(HannunTint.wash(category.color), in: .circle)
    }

    private func selectionMark(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? Constants.selectedSymbolName : Constants.unselectedSymbolName)
            .hannunFont(.sectionHeading)
            .foregroundStyle(isSelected ? Color.brand : Color.separator)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Constants.clearTitle) { viewModel.clearHoldings() }
                .disabled(viewModel.selectedHoldingIDs.isEmpty)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(Constants.doneTitle, systemImage: Constants.doneSymbolName) { dismiss() }
                .labelStyle(.iconOnly)
                .hannunButtonStyle(.sheetPrimary)
        }
    }
}

fileprivate enum Constants {
    static let title = "연결 종목"
    static let clearTitle = "전체 해제"
    static let doneTitle = "완료"
    static let doneSymbolName = "checkmark"
    static let selectedSymbolName = "checkmark.circle.fill"
    static let unselectedSymbolName = "circle"
    static let iconDiameter: CGFloat = 36
}
