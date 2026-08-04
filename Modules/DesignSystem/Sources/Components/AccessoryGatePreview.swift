//
//  AccessoryGatePreview.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

#if DEBUG
import SwiftUI

/// 게이트 검증 프리뷰 — 액세서리 단일 스트립 재정의(디자인 문서 §10)의 실기기 촬영용 매트릭스.
///
/// Feature 를 import 할 수 없으므로 4개 탭의 액세서리 상태를 DesignSystem 컴포넌트만으로
/// 재현한다. DEBUG 빌드를 실기기에 설치해 라이트/다크 × 투명도 감소 × 대비 증가 조합으로
/// 촬영하고, 합격 기준(G1~G4·G6·G8·G-스크롤)은 디자인 문서 §10 을 따른다. 시뮬레이터는
/// 유리 렌더링이 달라 판정 근거로 쓰지 않는다.
///
/// 선행 매트릭스의 G5(overflow 발견성)·G7(칩 4개 폭)은 대상이 사라져 셀도 함께 걷어냈다.
struct AccessoryGatePreview: View {

    // MARK: - Property

    private let layout: AccessoryLayout

    // MARK: - Body

    init(layout: AccessoryLayout = .expanded) {
        self.layout = layout
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingL) {
                gate("G1 — 성과: 비교 컨트롤 켜짐 vs 꺼짐 (채움 vs 스트로크)") {
                    standIn {
                        BottomAccessory {
                            comparisonStrip
                        } trailing: {
                            AccessoryControlButton("비교", isOn: true) {}
                        }
                    }
                    standIn {
                        BottomAccessory {
                            comparisonStrip
                        } trailing: {
                            AccessoryControlButton("비교", isOn: false) {}
                        }
                    }
                }

                gate("G2·G3 — 스트로크 컨트롤과 leading 문구의 구분 (RT/IC 조합에서 촬영)") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption(value: "12:04", suffix: "시세 기준")
                        } trailing: {
                            AccessoryControlButton("USD", isOn: false,
                                                   indicatesSelection: false) {}
                        }
                    }
                }

                // 셋을 붙여 두는 이유: 셰브런이 "여기서 화면이 열린다"만 뜻하고, 캡슐째
                // 버튼은 셰브런 없이도 눌린다는 게 이 매트릭스가 판정할 대비다. 가운데 줄이
                // "안 눌린다"로 읽히면 오른쪽 라벨의 brand 색만으로는 과녁 신호가 모자란 것이다.
                gate("G4 — chevron.up 이 \"화면이 열린다\"로 읽히는가 (여는 줄 vs 캡슐째 버튼 vs 안 눌리는 줄)") {
                    standIn {
                        BottomAccessory {
                            comparisonStrip
                        } trailing: {
                            AccessoryControlButton("비교", isOn: true) {}
                        }
                    }
                    standIn { portfolioSwitchStrip }
                    standIn {
                        BottomAccessory {
                            AccessoryCaption(.value("7건"), .plain("이번 달"))
                        } trailing: {
                            AccessoryActionButton("작성", systemImageName: "pencil.line") {}
                        }
                    }
                }

                gate("G6 — 선택 시트의 비활성(조회 실패) 행이 \"꺼짐\"으로 읽히는가") {
                    pickerRow(name: "S&P500", color: .categoryForeign, isSelected: true)
                    pickerRow(name: "나스닥", color: .categoryEtf, isSelected: false)
                    pickerRow(name: "BTC", color: .categoryCrypto, isSelected: false,
                              isAvailable: false)
                }

                gate("G8 — brand 스트로크·라벨 실측 대비 (선행 문서 §3.1 표 대조)") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption("아직 종목이 없어요")
                        } trailing: {
                            AccessoryControlButton("비교", isOn: false) {}
                        }
                    }
                }

                gate("G-스크롤 — §6 교대의 두 끝점 (전환 중 깜빡임은 실기기 스크롤로 판정)") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption(value: "12:04", suffix: "시세 기준")
                        } trailing: {
                            AccessoryControlButton("USD", isOn: false,
                                                   indicatesSelection: false) {}
                        }
                    }
                    standIn {
                        BottomAccessory {
                            AccessoryCaption(.value("₩1억 2,340만"))
                        } trailing: {
                            AccessoryControlButton("USD", isOn: false,
                                                   indicatesSelection: false) {}
                        }
                    }
                }

                gate("순자산: 로딩 / 갱신 실패 — 경고가 값보다 먼저다") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption("시세 불러오는 중")
                        } trailing: {
                            AccessoryControlButton("USD", isOn: false,
                                                   indicatesSelection: false) {}
                        }
                    }
                    standIn {
                        BottomAccessory {
                            StaleBadge(minutesElapsed: 7)
                        } trailing: {
                            AccessoryControlButton("USD", isOn: false,
                                                   indicatesSelection: false) {}
                        }
                    }
                }

                gate("매매일지: 기록 수 / 빈 상태 CTA") {
                    standIn {
                        BottomAccessory {
                            AccessoryCaption(.plain("이번 달"), .value("7건"))
                        } trailing: {
                            AccessoryActionButton("작성", systemImageName: "pencil.line") {}
                        }
                    }
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

    /// 성과 탭의 leading — 눌리는 한 줄이라 `chevron.up` 이 붙는다.
    private var comparisonStrip: some View {
        Button {} label: {
            AccessoryCaption(.plain("S&P500 대비"), .accent("+4.3%p", .gain))
                .dotted(.categoryForeign)
                .expandable()
        }
        .buttonStyle(.plain)
    }

    /// 포트폴리오 탭 — 캡슐 전체가 화면 전환 버튼이다. 셰브런은 붙지 않는다(무언가 열리는 게
    /// 아니라 탭 루트가 갈리는 것이므로). 오른쪽은 컨트롤이 아니라 **갈 화면 이름 라벨**이다.
    private var portfolioSwitchStrip: some View {
        Button {} label: {
            BottomAccessory {
                AccessoryCaption(.value("12종목"), .plain("· 12:04 기준"))
            } trailing: {
                Label("입출금 기록", systemImage: "arrow.left.arrow.right")
                    .hannunFont(.pillLabel)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: .minimumTouchTarget)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// 시트 행의 촬영 대역. 실제 행은 `BenchmarkPickerSheet` 에 있다.
    private func pickerRow(
        name: String,
        color: Color,
        isSelected: Bool,
        isAvailable: Bool = true
    ) -> some View {
        HStack(spacing: .spacingM) {
            CategoryDot(color: color)

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(name)
                    .hannunFont(.body)
                    .foregroundStyle(isAvailable ? Color.textPrimary : Color.textSecondary)

                if !isAvailable {
                    Text("지수를 불러오지 못했어요")
                        .hannunFont(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer(minLength: .spacingS)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(.horizontal, .spacingL)
        .frame(minHeight: .minimumTouchTarget)
        .frame(maxWidth: .infinity)
        .background(Color.surfacePrimary, in: .hannunContainer())
    }

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

#Preview("게이트 · 라이트") {
    AccessoryGatePreview()
        .preferredColorScheme(.light)
}

#Preview("게이트 · 다크") {
    AccessoryGatePreview()
        .preferredColorScheme(.dark)
}

#Preview("게이트 · 축약") {
    AccessoryGatePreview(layout: .inline)
        .preferredColorScheme(.dark)
}
#endif
