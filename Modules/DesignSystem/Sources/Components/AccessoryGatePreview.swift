//
//  AccessoryGatePreview.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

#if DEBUG
import HannunCore
import SwiftUI

/// 게이트 7 검증 프리뷰 — 액세서리 재제안(디자인 문서 §9)의 실기기 촬영용 매트릭스.
///
/// Feature 를 import 할 수 없으므로 4개 탭의 액세서리 상태를 DesignSystem 컴포넌트만으로
/// 재현한다. DEBUG 빌드를 실기기에 설치해 라이트/다크 × 투명도 감소 × 대비 증가 조합으로
/// 촬영하고, 합격 기준(G1~G8)은 디자인 문서 §9 를 따른다. 시뮬레이터는 유리 렌더링이 달라
/// 판정 근거로 쓰지 않는다.
struct AccessoryGatePreview: View {

    // MARK: - Property

    private let benchmarks: [(name: String, color: Color)] = [
        ("코스피", .categoryDomestic),
        ("S&P500", .categoryForeign),
        ("나스닥", .categoryEtf),
        ("BTC", .categoryCrypto),
    ]

    private let layout: AccessoryLayout

    @State private var currency: Currency = .krw
    @State private var selectedBenchmark = "S&P500"

    // MARK: - Body

    init(layout: AccessoryLayout = .expanded) {
        self.layout = layout
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingL) {
                gate("G1·G2 — 순자산: 2톤 캡션 + 토글 (선택/비선택 구분)") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption(value: "12:04", suffix: "시세 기준")
                        } trailing: {
                            CurrencyToggle(selection: $currency)
                        }
                    }
                }

                gate("순자산: 로딩 / stale") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption("시세 불러오는 중")
                        } trailing: {
                            CurrencyToggle(selection: $currency)
                        }
                    }
                    standIn {
                        BottomAccessory {
                            StaleBadge(minutesElapsed: 7)
                        } trailing: {
                            CurrencyToggle(selection: $currency)
                        }
                    }
                }

                gate("G4 — 포트폴리오: 보조 스트로크 vs 캡션 vs 주 액션") {
                    standIn {
                        BottomAccessory {
                            AccessoryActionButton(
                                "입출금 기록",
                                systemImageName: "arrow.left.arrow.right",
                                style: .secondary
                            ) {}
                        } trailing: {
                            AccessoryActionButton("종목 추가", systemImageName: "plus") {}
                        }
                    }
                }

                gate("G5 — 포트폴리오 inline: wash 원 overflow") {
                    standIn {
                        BottomAccessory {
                            Image(systemName: "ellipsis")
                                .hannunFont(.rowTitle)
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: .minimumTouchTarget, height: .minimumTouchTarget)
                                .background(HannunTint.neutralTint, in: .circle)
                        } trailing: {
                            AccessoryActionButton(
                                systemImageName: "plus",
                                accessibilityLabel: "종목 추가"
                            ) {}
                        }
                    }
                }

                gate("G1·G6·G7 — 성과: dot 칩 (선택/비선택/비활성)") {
                    standIn {
                        BottomAccessory {
                            ChipGroup(appearance: .accessory, scrollsHorizontally: false) {
                                ForEach(benchmarks, id: \.name) { benchmark in
                                    FilterChip(
                                        benchmark.name,
                                        isSelected: benchmark.name == selectedBenchmark,
                                        isEnabled: benchmark.name != "BTC",
                                        tint: benchmark.color
                                    ) {
                                        selectedBenchmark = benchmark.name
                                    }
                                }
                            }
                        }
                    }
                }

                gate("성과 inline: wash 메뉴 라벨") {
                    standIn {
                        BottomAccessory {
                            HStack(spacing: .spacingXS) {
                                CategoryDot(color: .categoryForeign)

                                Text("S&P500")
                                    .hannunFont(.pillLabel)
                                    .foregroundStyle(Color.textPrimary)

                                Image(systemName: "chevron.down")
                                    .imageScale(.small)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.vertical, .spacingS)
                            .padding(.horizontal, 14)
                            .background(HannunTint.wash(.categoryForeign), in: .capsule)
                        }
                    }
                }

                gate("매매일지: 힌트 + 작성 캡슐") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption("오늘의 매매를 기록해보세요")
                        } trailing: {
                            AccessoryActionButton("작성", systemImageName: "pencil.line") {}
                        }
                    }
                }
            }
            .padding(.spacingL)
        }
        .accessoryLayout(layout)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Function

    /// 앱에서는 시스템이 그리는 캡슐. 촬영용으로 같은 재질을 흉내 낸다 — 앱 코드 금지 패턴.
    private func standIn(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(height: layout == .inline ? Constants.inlineHeight : Constants.expandedHeight)
            .glassEffect(.regular, in: .capsule)
    }

    private func gate(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(title)
                .hannunFont(.caption)
                .foregroundStyle(Color.textSecondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

fileprivate enum Constants {
    /// 촬영 대역 전용 — 시스템 컨테이너 높이의 근사치다.
    static let expandedHeight: CGFloat = 56
    static let inlineHeight: CGFloat = 44
}

#Preview("게이트 7 · 라이트") {
    AccessoryGatePreview()
        .preferredColorScheme(.light)
}

#Preview("게이트 7 · 다크") {
    AccessoryGatePreview()
        .preferredColorScheme(.dark)
}

#Preview("게이트 7 · 축약") {
    AccessoryGatePreview(layout: .inline)
        .preferredColorScheme(.dark)
}
#endif
