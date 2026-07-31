//
//  Animation+Hannun.swift
//  HannunDesignSystem
//
//  Created by euijjang97 on 8/1/26.
//

import SwiftUI

/// UI 스펙 모션 가이드의 스프링 기본값. damping / response 조합을 이름으로 고정해
/// 컴포넌트마다 스프링 상수를 다시 적지 않게 한다.
///
/// 기본은 critically damped(1.0) 다. **bounce(0.8)는 사용자 제스처가 모멘텀을 실었을 때만** 쓴다
/// — 그냥 나타나는 메뉴에 overshoot 를 주면 물리적으로 거짓말이 된다.
public enum HannunMotion: CaseIterable, Sendable {
    /// 접기/펼치기, 값 전환, 필터 적용. damping 1.0 / response 0.35.
    case standard
    /// 칩 선택, 통화 토글. damping 1.0 / response 0.30.
    case selection
    /// sheet 드래그 해제, 스와이프, 플릭. damping 0.8 / response 0.30.
    case momentum
    /// sheet 등장. damping 1.0 / response 0.40.
    case sheet
}

public extension HannunMotion {
    var animation: Animation {
        switch self {
        case .standard:
            .spring(response: 0.35, dampingFraction: 1.0)
        case .selection:
            .spring(response: 0.30, dampingFraction: 1.0)
        case .momentum:
            .spring(response: 0.30, dampingFraction: 0.8)
        case .sheet:
            .spring(response: 0.40, dampingFraction: 1.0)
        }
    }

    /// Reduce Motion 대체. 슬라이드·스프링을 짧은 크로스페이드로 낮추고 overshoot 를 전면 제거한다.
    var reducedMotion: Animation {
        .easeInOut(duration: Constants.reducedMotionDuration)
    }
}

public extension View {
    /// 모션 토큰을 적용한다. Reduce Motion 이 켜져 있으면 크로스페이드로 자동 대체된다 —
    /// 접근성 분기를 컴포넌트마다 반복하지 않기 위해 이 한 곳에 모은다.
    func hannunAnimation(_ motion: HannunMotion, value: some Equatable) -> some View {
        modifier(MotionModifier(motion: motion, value: value))
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {

    // MARK: - Property

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let motion: HannunMotion
    let value: Value

    // MARK: - Body

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? motion.reducedMotion : motion.animation, value: value)
    }
}

fileprivate enum Constants {
    static let reducedMotionDuration: TimeInterval = 0.15
}
