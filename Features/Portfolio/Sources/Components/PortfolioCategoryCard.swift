//
//  PortfolioCategoryCard.swift
//  PortfolioFeature
//
//  Created by euijjang97 on 8/3/26.
//

import HannunCore
import HannunDesignSystem
import HannunDomain
import SwiftUI

/// 카테고리 한 묶음을 담는 surface 카드 (시안 §6.2).
///
/// **카드는 좌우 패딩을 갖지 않는다.** 행이 자기 좌우 16pt 를 소유해야 행 사이 구분선을
/// 그 여백에서 끊을 수 있기 때문이다 — 카드가 패딩을 가지면 구분선이 카드 안쪽 끝까지
/// 꽉 차서 리스트가 표처럼 읽힌다. 헤더만 같은 폭의 `[0, 16]` 래퍼에 넣어 행과 좌우를 맞춘다.
///
/// 수정/삭제를 `swipeActions` 가 아니라 `contextMenu` 로 내는 이유는 이 구조 자체다.
/// 헤더와 행이 하나의 카드를 공유하는 배치는 `List` 의 섹션 모델(헤더 = 행 배경 바깥)로
/// 만들 수 없어 `ScrollView` 로 내려왔고, 그 대가로 스와이프 편집을 잃었다.
struct PortfolioCategoryCard: View {

    // MARK: - Property

    let section: PortfolioSection
    let metric: HoldingMetric
    @Binding var isExpanded: Bool
    let onMetricTap: () -> Void
    let onEdit: (HoldingValuation) -> Void
    let onDelete: (HoldingValuation) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            CategorySectionHeader(
                category: section.category,
                title: section.category.title,
                subtotal: section.subtotal,
                isExpanded: $isExpanded
            )
            .padding(.horizontal, .spacingL)

            if isExpanded {
                ForEach(Array(section.valuations.enumerated()), id: \.element.id) { index, valuation in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, .spacingL)
                    }

                    row(for: valuation)
                }
            }
        }
        .padding(.vertical, .spacingS)
        .background(Color.surfacePrimary, in: .hannunContainer())
        .hannunAnimation(.standard, value: isExpanded)
    }

    // MARK: - Function

    private func row(for valuation: HoldingValuation) -> some View {
        HoldingValuationRow(valuation: valuation, metric: metric, onMetricTap: onMetricTap)
            .contextMenu {
                Button {
                    onEdit(valuation)
                } label: {
                    Label(Constants.editTitle, systemImage: Constants.editSymbolName)
                }

                Button(role: .destructive) {
                    onDelete(valuation)
                } label: {
                    Label(Constants.deleteTitle, systemImage: Constants.deleteSymbolName)
                }
            }
    }
}

fileprivate enum Constants {
    static let editTitle = "수정"
    static let deleteTitle = "삭제"
    static let editSymbolName = "pencil"
    static let deleteSymbolName = "trash"
}

#if DEBUG
private struct PortfolioCategoryCardPreview: View {

    // MARK: - Property

    @State private var isDomesticExpanded = true
    @State private var isCashExpanded = true
    @State private var metric: HoldingMetric = .returnRate

    private var domestic: PortfolioSection {
        PortfolioSection(
            category: .domesticStock,
            subtotal: .krw(43_676_000),
            valuations: [
                valuation(name: "삼성전자", ticker: "005930", quantity: 10, average: 61_300, price: 67_100),
                valuation(name: "SK하이닉스", ticker: "000660", quantity: 15, average: 198_400, price: 217_000),
            ]
        )
    }

    private var cash: PortfolioSection {
        PortfolioSection(
            category: .cash,
            subtotal: .krw(12_300_000),
            valuations: [
                HoldingValuation(
                    holding: HoldingRecord(category: .cash, name: "원화 현금", quantity: 12_300_000),
                    currentPrice: nil,
                    marketValue: .krw(12_300_000),
                    costBasis: nil,
                    priceFreshness: .notApplicable
                ),
            ]
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: .spacingM) {
                PortfolioCategoryCard(
                    section: domestic,
                    metric: metric,
                    isExpanded: $isDomesticExpanded,
                    onMetricTap: { metric = metric.next },
                    onEdit: { _ in },
                    onDelete: { _ in }
                )

                PortfolioCategoryCard(
                    section: cash,
                    metric: metric,
                    isExpanded: $isCashExpanded,
                    onMetricTap: { metric = metric.next },
                    onEdit: { _ in },
                    onDelete: { _ in }
                )
            }
            .padding(.top, .spacingM)
            .padding(.horizontal, .spacingL)
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    private func valuation(
        name: String,
        ticker: String,
        quantity: Decimal,
        average: Decimal,
        price: Decimal
    ) -> HoldingValuation {
        HoldingValuation(
            holding: HoldingRecord(
                category: .domesticStock,
                name: name,
                ticker: ticker,
                quantity: quantity,
                averagePrice: average
            ),
            currentPrice: .krw(price),
            marketValue: .krw(price * quantity),
            costBasis: .krw(average * quantity),
            priceFreshness: .fresh(asOf: .now)
        )
    }
}

#Preview("카테고리 카드 · 라이트") {
    PortfolioCategoryCardPreview()
        .preferredColorScheme(.light)
}

#Preview("카테고리 카드 · 다크") {
    PortfolioCategoryCardPreview()
        .preferredColorScheme(.dark)
}
#endif
