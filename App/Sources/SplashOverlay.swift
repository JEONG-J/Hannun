//
//  SplashOverlay.swift
//  Hannun
//
//  Created by euijjang97 on 8/10/26.
//

import SwiftUI

/// 정적 런치 화면(`Info.plist` 의 `UILaunchScreen`)을 이어받아 화면에 더 머무는 덮개.
///
/// 런치 화면 자체는 붙잡아 둘 수 없다 — iOS 가 첫 프레임이 준비되는 즉시 걷어낸다. 그래서
/// **같은 배경 · 같은 크기의 로고**를 한 장 더 그려 교대가 보이지 않게 한다. 에셋도 런치
/// 화면이 쓰는 것을 그대로 쓴다(`LaunchBackground` · `LaunchLogo`, 둘 다 main bundle) —
/// 한쪽만 갈아 끼우면 교대하는 순간 배경이 튀거나 로고가 점프한다.
struct SplashOverlay: View {

    // MARK: - Body

    var body: some View {
        Color(Constants.backgroundAssetName)
            .ignoresSafeArea()
            .overlay {
                // `.resizable()` 도 `.frame` 도 걸지 않는다. 런치 화면은 이 에셋을 확대·축소
                // 없이 원본 포인트 크기(160pt) 그대로 화면 중앙에 놓으므로, 여기서 크기를
                // 정하는 순간 그 값과 어긋난다.
                Image(Constants.logoAssetName)
                    // 장식이다. 라벨을 주지 않으면 VoiceOver 가 에셋 이름을 읽는다.
                    .accessibilityHidden(true)
            }
    }
}

fileprivate enum Constants {
    static let backgroundAssetName = "LaunchBackground"
    static let logoAssetName = "LaunchLogo"
}

#if DEBUG
#Preview("스플래시 · 라이트") {
    SplashOverlay()
        .preferredColorScheme(.light)
}

#Preview("스플래시 · 다크") {
    SplashOverlay()
        .preferredColorScheme(.dark)
}
#endif
