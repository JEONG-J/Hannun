//
//  CGFloat+Hannun.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 7/31/26.
//

import SwiftUI

/// UI 스펙 스페이싱 스케일. `CGFloat` 에 얹어 리딩 닷으로 바로 쓴다 —
/// `VStack(spacing: .spacingL)` / `.padding(.horizontal, .spacingL)`.
public extension CGFloat {
    /// dot–텍스트 간격, pill 내부 상하.
    static let spacingXS: CGFloat = 4
    /// 행 내부 요소 간격, 칩 간격.
    static let spacingS: CGFloat = 8
    /// 카드 내부 패딩(컴팩트), 셀 상하.
    static let spacingM: CGFloat = 12
    /// 화면 좌우 마진, 카드 내부 패딩(기본).
    static let spacingL: CGFloat = 16
    /// 섹션 간 간격.
    static let spacingXL: CGFloat = 24
    /// 큰 숫자 블록 상하 여백.
    static let spacingXXL: CGFloat = 32
}

public extension CGFloat {
    /// HIG 최소 터치 타깃. 라벨이 작아도 탭 영역은 이 값 아래로 내려가지 않는다.
    static let minimumTouchTarget: CGFloat = 44
}

/// UI 스펙 코너 반경. 컨테이너 클리핑은 `ConcentricRectangle` 패턴을 함께 쓴다 —
/// `.clipShape(.rect(corners: .concentric(minimum: .fixed(.radiusM)), isUniform: true))`.
/// 칩·pill·토글·세그먼트는 반경 토큰이 아니라 `.capsule` 이다.
public extension CGFloat {
    /// 작은 배지·인풋 필드.
    static let radiusS: CGFloat = 8
    /// 카드·차트 컨테이너·리스트 그룹.
    static let radiusM: CGFloat = 16
    /// sheet 상단.
    static let radiusL: CGFloat = 24
}

#if DEBUG
private struct LayoutTokenPreview: View {

    // MARK: - Property

    private let spacings: [(name: String, value: CGFloat)] = [
        ("spacingXS", .spacingXS),
        ("spacingS", .spacingS),
        ("spacingM", .spacingM),
        ("spacingL", .spacingL),
        ("spacingXL", .spacingXL),
        ("spacingXXL", .spacingXXL),
    ]

    private let radii: [(name: String, value: CGFloat)] = [
        ("radiusS", .radiusS),
        ("radiusM", .radiusM),
        ("radiusL", .radiusL),
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXL) {
            VStack(alignment: .leading, spacing: .spacingS) {
                Text("스페이싱")
                    .hannunFont(.sectionHeading)
                    .foregroundStyle(Color.textPrimary)

                ForEach(spacings, id: \.name) { item in
                    HStack(spacing: .spacingM) {
                        Rectangle()
                            .fill(Color.brand)
                            .frame(width: item.value, height: 20)

                        Text("\(item.name) · \(Int(item.value))pt")
                            .hannunFont(.caption, tabularFigures: true)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: .spacingS) {
                Text("코너 반경")
                    .hannunFont(.sectionHeading)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: .spacingM) {
                    ForEach(radii, id: \.name) { item in
                        VStack(spacing: .spacingXS) {
                            RoundedRectangle(cornerRadius: item.value)
                                .fill(Color.surfacePrimary)
                                .frame(width: 72, height: 72)

                            Text("\(item.name) · \(Int(item.value))pt")
                                .hannunFont(.caption, tabularFigures: true)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingL)
        .background(Color.backgroundPrimary)
    }
}

#Preview("레이아웃 토큰 · 라이트") {
    LayoutTokenPreview()
        .preferredColorScheme(.light)
}

#Preview("레이아웃 토큰 · 다크") {
    LayoutTokenPreview()
        .preferredColorScheme(.dark)
}
#endif
