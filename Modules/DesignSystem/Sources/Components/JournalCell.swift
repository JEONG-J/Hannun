//
//  JournalCell.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore
import SwiftUI

/// 매매일지 리스트 셀.
///
/// 날짜 문구는 문자열로 받는다 — "오늘"/"어제" 로 쓸지 "7월 25일 (금)" 으로 쓸지는 제품 규칙이라
/// 디자인 시스템이 정할 일이 아니다.
///
/// 태그가 없으면 태그 행 자체를 그리지 않는다. 빈 행을 남기면 셀 높이가 들쭉날쭉해 보인다.
public struct JournalCell: View {

    // MARK: - Property

    private let dateText: String
    private let title: String
    private let preview: String
    private let tags: [JournalTag]

    // MARK: - Body

    public init(dateText: String, title: String, preview: String, tags: [JournalTag] = []) {
        self.dateText = dateText
        self.title = title
        self.preview = preview
        self.tags = tags
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(dateText)
                .hannunFont(.caption, tabularFigures: true)
                .foregroundStyle(Color.textSecondary)

            Text(title)
                .hannunFont(.rowTitle)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(preview)
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)

            if !tags.isEmpty {
                tagRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingL)
        .background(Color.surfacePrimary, in: .hannunContainer())
    }

    /// "+n" 만 분류색을 입지 않는다 — 가려진 태그들의 분류가 하나가 아니라서 어떤 색을 골라도
    /// 거짓말이 된다.
    private var tagRow: some View {
        HStack(spacing: .spacingXS) {
            ForEach(tags.prefix(Constants.visibleTagLimit)) { tag in
                TagPill(tag.name, category: tag.category)
            }

            if overflowCount > 0 {
                TagPill("+\(overflowCount)")
            }
        }
        .padding(.top, .spacingXS)
    }

    // MARK: - Function

    private var overflowCount: Int {
        max(0, tags.count - Constants.visibleTagLimit)
    }
}

fileprivate enum Constants {
    /// 넷 이상이면 태그가 제목보다 넓어져 셀의 주인공이 바뀐다.
    static let visibleTagLimit = 3
}

#if DEBUG
private struct JournalCellPreview: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingM) {
            JournalCell(
                dateText: "오늘",
                title: "반도체 비중을 절반으로 줄였다",
                preview: "환율이 더 밀릴 것 같아 해외 비중부터 정리했다. 다음 분기 실적을 보고…",
                tags: [
                    tag("삼성전자", .domesticStock),
                    tag("SK하이닉스", .domesticStock),
                    tag("NVDA", .overseasStock),
                    tag("BTC", .crypto),
                ]
            )

            JournalCell(
                dateText: "7월 25일 (금)",
                title: "현금 비중 20% 유지 결정",
                preview: "지수가 고점이라 추가 매수는 보류. 배당 입금분만 예수금에 남겨둔다.",
                tags: [tag("원화 예수금", .cash)]
            )

            JournalCell(
                dateText: "7월 21일 (월)",
                title: "매매 없음",
                preview: "관망. 특별한 판단 근거가 없어서 아무것도 하지 않았다."
            )
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private func tag(_ name: String, _ category: AssetCategory) -> JournalTag {
        JournalTag(id: UUID(), name: name, category: category)
    }
}

#Preview("일지 셀 · 라이트") {
    JournalCellPreview()
        .preferredColorScheme(.light)
}

#Preview("일지 셀 · 다크") {
    JournalCellPreview()
        .preferredColorScheme(.dark)
}
#endif
