//
//  PeriodMenu.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/6/26.
//

import SwiftUI

/// 기간을 고르는 축약 메뉴 캡슐. 차트 카드 헤더에서 단위 세그먼트 왼쪽에 선다.
///
/// 6칸을 다 펼치면 같은 줄의 범례와 단위 세그먼트를 밀어내므로 **고른 하나만** 보여 주고
/// 나머지는 메뉴로 접는다. 대신 재질·서체·높이는 옆의 `SegmentedPicker` 와 같은 값을 쓴다 —
/// 한 줄에 나란히 서는 두 컨트롤이 서로 다른 유리를 두르면 카드 안에 도구모음이 생긴 것처럼 보인다.
public struct PeriodMenu: View {

    // MARK: - Property

    @Binding private var selection: ChartPeriod

    private let onCustomRequested: () -> Void

    // MARK: - Body

    public init(selection: Binding<ChartPeriod>, onCustomRequested: @escaping () -> Void) {
        _selection = selection
        self.onCustomRequested = onCustomRequested
    }

    public var body: some View {
        Menu {
            // `Picker` 에 맡기면 iOS 가 고른 항목에 체크마크를 대신 그린다. 직접 고른 구간은
            // 어느 프리셋과도 태그가 맞지 않아 체크가 하나도 서지 않는다 — 그 빈 자리가
            // "프리셋이 아니다" 를 말한다. 무엇을 골랐는지는 알약 라벨이 이미 적고 있다.
            Picker(Constants.accessibilityLabel, selection: $selection) {
                ForEach(ChartPeriod.presets) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button(Constants.customTitle) { onCustomRequested() }
        } label: {
            label
        }
        .buttonStyle(.plain)
        .hannunGlass(.periodSegment)
        .hannunAnimation(.selection, value: selection)
        // 라벨만 읽히면 "1개월" 이 무엇의 1개월인지 말하지 못한다.
        .accessibilityLabel(Constants.accessibilityLabel)
        .accessibilityValue(selection.title)
    }

    // MARK: - Function

    private var label: some View {
        HStack(spacing: .spacingXS) {
            Text(selection.title)

            Image(systemName: Constants.expandSymbolName)
        }
        .hannunFont(.pillLabel)
        .foregroundStyle(Color.brand)
        .lineLimit(1)
        .minimumScaleFactor(Constants.minimumLabelScale)
        .padding(.horizontal, .spacingM)
        .frame(minHeight: Constants.capsuleHeight)
        .contentShape(.capsule)
    }
}

fileprivate enum Constants {
    static let accessibilityLabel = "기간"
    static let customTitle = "직접 선택…"
    static let expandSymbolName = "chevron.down"
    /// AX 사이즈에서 라벨이 잘리느니 줄어드는 편이 낫다. 지금 무엇을 보고 있는지 말하는
    /// 유일한 단서라 말줄임으로 지워질 수 없다. 프리셋 기준이면 0.8 로도 남지만
    /// "2026.1 – 2026.8" 은 다섯 배 길어 옆의 단위 세그먼트가 설 자리까지 먹는다 —
    /// 격자·캘린더 헤더가 쓰는 0.7 과 같은 값으로 맞춘다.
    static let minimumLabelScale: CGFloat = 0.7
    /// 옆의 `SegmentedPicker` 는 44pt 터치 타깃 둘레에 4pt 트랙 여백을 두르므로 유리 높이가
    /// 52pt 다. 같은 줄에서 두 캡슐의 밑변이 어긋나지 않으려면 여기도 같은 값을 쓴다.
    static let capsuleHeight: CGFloat = .minimumTouchTarget + 8
}

#if DEBUG
private struct PeriodMenuPreview: View {

    // MARK: - Property

    @State private var period: ChartPeriod
    @State private var granularity = "일별"

    /// 차트 카드 내폭. 라벨이 길어졌을 때 옆의 세그먼트가 남는지 실제 폭에서 본다.
    private let cardWidth: CGFloat = 329

    /// 알약 라벨이 가장 길어지는 꼴 — 커스텀 구간의 AX5 확인은 이 값으로 한다.
    static var customPeriod: ChartPeriod {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 1)) ?? .now
        let end = calendar.date(from: DateComponents(year: 2026, month: 8)) ?? .now

        return .custom(start: start, end: end)
    }

    // MARK: - Body

    init(period: ChartPeriod = .yearToDate) {
        _period = State(initialValue: period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            Text("선택: \(period.title)")
                .hannunFont(.subtext)
                .foregroundStyle(Color.textSecondary)

            // 차트 카드 헤더와 같은 조합 — 두 캡슐의 높이·재질이 맞는지 여기서 본다.
            HStack(spacing: .spacingS) {
                PeriodMenu(selection: $period) {}

                SegmentedPicker(["일별", "월별"], selection: $granularity) { $0 }
            }
            .frame(width: cardWidth)
        }
        .padding(.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }
}

#Preview("기간 메뉴 · 라이트") {
    PeriodMenuPreview()
        .preferredColorScheme(.light)
}

#Preview("기간 메뉴 · 다크") {
    PeriodMenuPreview()
        .preferredColorScheme(.dark)
}

/// 직접 고른 구간. 알약이 "2026.1 – 2026.8" 을 담고도 세그먼트가 옆에 서는지 본다.
#Preview("기간 메뉴 · 직접 선택") {
    PeriodMenuPreview(period: PeriodMenuPreview.customPeriod)
}

/// 라벨이 말줄임 없이 캡슐 안에 남는지 확인한다.
#Preview("기간 메뉴 · AX5") {
    PeriodMenuPreview()
        .dynamicTypeSize(.accessibility5)
}

#Preview("기간 메뉴 · 직접 선택 AX5") {
    PeriodMenuPreview(period: PeriodMenuPreview.customPeriod)
        .dynamicTypeSize(.accessibility5)
}
#endif
