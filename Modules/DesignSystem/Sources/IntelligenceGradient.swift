//
//  IntelligenceGradient.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/3/26.
//

import SwiftUI

/// Apple Intelligence 표식(`apple.intelligence`)에 입히는 무지개.
///
/// 이 앱의 색은 전부 뜻을 지고 있다 — 빨강은 상승, 파랑은 하락, `brand` 는 우리가 만든 동작이다.
/// 모델이 쓴 글로 들어가는 입구를 그중 하나로 칠하면 그 자리가 앱 안의 평범한 버튼으로
/// 내려앉고, 손익 색을 빌려 쓰면 "빨강 = 상승" 규칙까지 흔들린다. 그래서 어느 토큰도 쓰지 않는
/// **이 표식 전용 색**을 따로 세운다. 다른 자리에서는 쓰지 않는다.
///
/// 심볼 자체는 `.symbolRenderingMode(.multicolor)` 로도 색이 붙지 않는다 — 시스템이 들고 있는
/// 건 단색 도형뿐이라 무지개는 우리가 입혀야 한다.
public extension ShapeStyle where Self == AngularGradient {

    /// 각도로 두르는 이유는 심볼이 고리라서다. 선형으로 쓸면 고리의 왼쪽 위와 오른쪽 아래가
    /// 같은 색이 되어 겹친 매듭이 한 덩어리로 보인다. 각도로 두르면 색이 고리를 따라 돈다.
    static var intelligence: AngularGradient {
        AngularGradient(colors: Constants.rainbow, center: .center)
    }
}

fileprivate enum Constants {

    /// 시작색으로 되돌아와 닫는다 — 끝과 처음이 다르면 고리에 이음매 한 줄이 남는다.
    ///
    /// 흔한 무지개보다 한 단 짙다. 툴바 유리와 다크 배경 **양쪽**에 같은 심볼이 얹히는데,
    /// 순수한 노랑·연두는 밝은 유리 위에서 획이 사라진다.
    static let rainbow: [Color] = [
        Color(red: 1.00, green: 0.18, blue: 0.47),
        Color(red: 1.00, green: 0.48, blue: 0.00),
        Color(red: 0.91, green: 0.65, blue: 0.00),
        Color(red: 0.09, green: 0.70, blue: 0.41),
        Color(red: 0.00, green: 0.66, blue: 0.75),
        Color(red: 0.15, green: 0.39, blue: 0.92),
        Color(red: 0.49, green: 0.23, blue: 0.93),
        Color(red: 1.00, green: 0.18, blue: 0.47),
    ]

    static let symbolName = "apple.intelligence"
}

#if DEBUG
private struct IntelligenceGradientPreview: View {

    // MARK: - Body

    var body: some View {
        HStack(spacing: .spacingXL) {
            ForEach([Font.TextStyle.body, .title2, .largeTitle], id: \.self) { style in
                Image(systemName: Constants.symbolName)
                    .font(.system(style))
                    .foregroundStyle(.intelligence)
            }
        }
        .padding(.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview("Apple Intelligence 표식 · 라이트") {
    IntelligenceGradientPreview()
        .preferredColorScheme(.light)
}

#Preview("Apple Intelligence 표식 · 다크") {
    IntelligenceGradientPreview()
        .preferredColorScheme(.dark)
}
#endif
