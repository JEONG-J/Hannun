//
//  BottomAccessory.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import HannunCore
import SwiftUI

/// 탭바 하단 액세서리 캡슐. `tabViewBottomAccessory(content:)` 안에 넣어 쓴다.
///
/// blur 와 그림자를 직접 얹지 않는다 — 시안의 `background_blur(20)` + shadow 는 Liquid Glass 의
/// 모사이고 실제 재질에는 이미 들어 있다. 두 번 얹으면 탁해진다.
///
/// 내부 컨트롤에는 glass 를 다시 쓰지 않는다. 캡슐이 이미 반투명 면이라 그 위에 반투명을 겹치면
/// 두 겹이 되어 가독성이 무너진다. `ChipGroup(appearance: .accessory)` ·
/// `AccessoryActionButton` 이 이 규칙을 이미 지키고 있으므로 그대로 담으면 된다.
///
/// `.expanded` / `.inline` 분기는 담는 쪽이 `@Environment(\.tabViewBottomAccessoryPlacement)` 로
/// 처리한다 — 축약 규칙이 탭마다 다르므로 캡슐이 정할 수 있는 일이 아니다.
public struct BottomAccessory<Content: View>: View {

    // MARK: - Property

    private let content: Content

    // MARK: - Body

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: .spacingS) { content }
            .padding(Constants.capsulePadding)
            .frame(height: Constants.capsuleHeight)
            .hannunGlass(.accessoryCapsule)
    }
}

fileprivate enum Constants {
    static let capsuleHeight: CGFloat = 56
    /// 스펙이 지정한 캡슐 내부 여백. 44pt 터치 타깃을 56pt 안에 담기 위한 값이라
    /// 스페이싱 스케일 밖이다.
    static let capsulePadding: CGFloat = 6
}

#if DEBUG
private struct BottomAccessoryPreview: View {

    // MARK: - Property

    private let benchmarks: [(name: String, color: Color)] = [
        ("코스피", .categoryDomestic),
        ("S&P500", .categoryForeign),
        ("나스닥", .categoryEtf),
        ("BTC", .categoryCrypto),
    ]

    @State private var currency: Currency = .krw
    @State private var selectedBenchmark = "S&P500"

    // MARK: - Body

    var body: some View {
        VStack(spacing: .spacingL) {
            netWorthAccessory
            portfolioAccessory
            performanceAccessory
            journalAccessory
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    private var netWorthAccessory: some View {
        BottomAccessory {
            Label("오후 12:04 시세 기준", systemImage: "arrow.clockwise")
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
                .padding(.leading, .spacingS)

            Spacer(minLength: .spacingS)

            CurrencyToggle(selection: $currency)
        }
    }

    private var portfolioAccessory: some View {
        BottomAccessory {
            AccessoryActionButton("종목 추가", systemImageName: "plus", style: .primary) {}

            Spacer(minLength: .spacingS)

            AccessoryActionButton(
                "입출금 기록",
                systemImageName: "arrow.left.arrow.right",
                style: .secondary
            ) {}
        }
    }

    private var performanceAccessory: some View {
        BottomAccessory {
            ChipGroup(appearance: .accessory, scrollsHorizontally: false) {
                ForEach(benchmarks, id: \.name) { benchmark in
                    FilterChip(
                        benchmark.name,
                        isSelected: benchmark.name == selectedBenchmark,
                        tint: benchmark.color
                    ) {
                        selectedBenchmark = benchmark.name
                    }
                }
            }
        }
    }

    private var journalAccessory: some View {
        BottomAccessory {
            Label("오늘의 매매를 기록해보세요", systemImage: "sparkles")
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)
                .padding(.leading, .spacingS)

            Spacer(minLength: .spacingS)

            AccessoryActionButton(systemImageName: "pencil.line") {}
        }
    }
}

#Preview("하단 액세서리 · 라이트") {
    BottomAccessoryPreview()
        .preferredColorScheme(.light)
}

#Preview("하단 액세서리 · 다크") {
    BottomAccessoryPreview()
        .preferredColorScheme(.dark)
}
#endif
