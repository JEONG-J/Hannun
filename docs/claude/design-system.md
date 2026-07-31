# 디자인 시스템 + 성능 최적화

> Glass Effect, 렌더링 최적화 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고. iOS 26 프레임워크 API 상세는 `docs/claude/ios26-frameworks/` 참고.

## 디자인 토큰 (프로젝트별 정의)

레이아웃 상수(여백·모서리 반경 등을 담는 enum), Typography 스케일, 공용 UI 컴포넌트는
프로젝트마다 별도로 정의한다. 이 문서에는 플랫폼 공통 패턴만 남기고, 실제 토큰 값과
컴포넌트 목록은 프로젝트의 디자인 시스템 모듈에서 관리한다.

## Shape 패턴 (권장)

```swift
// ConcentricRectangle 사용 (디바이스별 일관성)
.clipShape(
    ConcentricRectangle(
        corners: .concentric(minimum: cornerRadius),
        isUniform: true
    )
)
.containerShape(.rect(corners: .concentric(minimum: cornerRadius)))
```

> `cornerRadius`는 프로젝트의 레이아웃 상수 정의를 사용한다.

## Glass Effect 선택

| Variant | 용도 |
|---------|------|
| `.regular` | 일반 카드, 폼 |
| `.regular.interactive()` | 탭 가능 요소 |
| `.clear` | 미디어/색상 배경 위 |
| `.glassProminent` (ButtonStyle) | Primary 버튼 |
| `.glass` (ButtonStyle) | Secondary 버튼 |

> Liquid Glass API 전체 사용법은 `docs/claude/ios26-frameworks/SwiftUI-Implementing-Liquid-Glass-Design.md` 참고.

## 성능 최적화

### Liquid Glass (iOS 26)

- `GlassEffectContainer`로 그룹화 필수 (오프스크린 렌더링 66% 감소)
- `glassEffectID`는 모핑 애니메이션 필요 시만 사용 (CPU 부하)
- 적용 불가: List, Table, 미디어 콘텐츠

### View 렌더링

- Container-Presenter 패턴: Container(상태/로직) + Presenter(UI + Equatable)
- 클로저는 Equatable 비교에서 제외

```swift
struct CardPresenter: View, Equatable {
    let id: UUID
    let name: String
    var onTap: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

### List/ForEach

- List 우선 사용 (LazyVStack보다 뷰 재사용 효율적)
- ForEach 내 조건부 뷰 금지 (lazy loading 깨짐)
- List에서 `.id()` 모디파이어 사용 금지
