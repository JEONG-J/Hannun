# 순자산 자산배분 카드 재설계

- 작성일: 2026-08-03
- 대상: 순자산 탭 `AllocationCard` (NW-3 비중 도넛 / NW-4 카테고리 소계)
- 관련 문서: `docs/design/2026-07-27-ui-design-spec.md` §4.1,
  `docs/design/2026-07-31-pencil-design-reference.md` §6.1

## 1. 문제

순자산 탭의 자산배분 카드에 두 가지 문제가 있다.

**도넛에서 값을 보는 방법이 화면에 드러나지 않는다.** 지금은 `chartAngleSelection(value:)`
하나로 상호작용을 처리해서, 섹터를 **누른 채 끌어야만** 값이 나타나고 손을 떼면 사라진다.
그렇게 할 수 있다는 단서가 화면 어디에도 없다. UI 스펙 §4.1 이 정의한 동작은 원래 탭이었다 —
"도넛 섹터 탭: 해당 섹터 강조 + 중앙 홀 값이 카테고리명/금액으로 전환. 재탭 시 총액 복귀".
구현이 스펙에서 벗어난 상태다.

**소계 리스트가 비중을 읽기 어렵다.** 다섯 행이 같은 무게로 나열되고, 비중은 줄 끝의 작은
퍼센트 숫자 하나뿐이다. 어느 자산군이 큰지 보려면 숫자를 하나씩 비교해야 한다. 정렬도
`AssetCategory` 선언 순서(현금 → 국내주식 → 해외주식 → ETF → 코인)라 크기와 무관하다.
시안(§6.1)은 34 / 26 / 18 / 12 / 10 내림차순이고, 그래서 도넛 12시에 가장 큰 자산군이 온다.
현재 구현에서는 현금이 12시를 차지한다.

행별 **전일 대비 증감**은 이번 범위에서 뺀다. `CategoryBreakdown` 은
`category` / `amount` / `weight` 만 들고 있어서 Domain·Repository·스냅샷 비교까지 손대야 한다.
카드 시각 개선의 범위를 넘는다.

## 2. 도넛 제스처

`chartAngleSelection` 을 걷어내고 제스처를 직접 단다. 프레임워크 선택과 우리 탭 토글을 같이
두면 "같은 섹터 재탭 → 우리가 `nil` 로 지움 → 프레임워크가 곧바로 다시 채움" 이 되어 해제가
동작하지 않는다. 선택의 출처는 하나여야 한다.

`DonutChart` 에 `DragGesture(minimumDistance: 0)` 하나를 단다.

| 이벤트 | 조건 | 동작 |
|--------|------|------|
| `onChanged` | 이동 거리가 `scrubThreshold` 초과 | 스크럽 — `selection = category(at:)` |
| `onEnded` | 스크럽이 아니었다 (= 탭) | 같은 카테고리면 `nil`, 아니면 그 카테고리 |
| `onEnded` | 스크럽이었다 | 마지막 선택을 **유지** (지금처럼 사라지지 않는다) |

스크럽 여부는 `@State private var isScrubbing` 으로 들고, `onEnded` 에서 읽고 되돌린다.

### 2.1 히트 테스트

각도 → 카테고리 매핑을 순수 함수로 분리해 단위 테스트한다.

```swift
func category(at point: CGPoint, in size: CGSize) -> AssetCategory?
```

1. 중심에서의 거리를 잰다. **안쪽 홀(반지름 × `innerRadiusRatio`) 미만이거나 바깥 반지름을
   넘으면 `nil`** — 홀을 눌렀는데 엉뚱한 섹터가 잡히는 일을 막는다.
2. 12시 기준 시계방향 각도를 `[0, 2π)` 로 구한다. `SectorMark` 의 기본 배치와 같다.
3. 각도 비율 × 전체 `chartValue` 합 → 누적 값으로 카테고리를 찾는다. 이 매핑은 기존
   `category(atAngleValue:)` 를 그대로 쓴다.

선택 섹터를 1.04배로 키우는 `outerRadiusRatio` 는 히트 테스트에서 무시한다. 확대는 선택된
뒤에만 일어나므로 판정 기준으로 삼으면 같은 지점의 결과가 선택 상태에 따라 달라진다.

### 2.2 중앙 홀

지금 홀은 히어로와 똑같은 총자산을 두 번째로 말한다. 정보가 없는 자리이므로 어포던스에 쓴다.

| 상태 | 내용 |
|------|------|
| 미선택 | `hand.tap` 심볼 + `"눌러서 자산군별 보기"` (`.caption`, `textSecondary`) |
| 선택됨 | 카테고리명 (`.caption`, `textSecondary`) + `AmountText(.row)` — 현재와 동일 |

AX 사이즈(`dynamicTypeSize.isAccessibilitySize`)에서는 심볼을 빼고 문구만 둔다. 홀 지름이
124pt(200 × 0.62)라 둘 다 들어가지 않는다.

`totalLabel` / `total` 파라미터는 더 이상 쓰이지 않으므로 `DonutChart` 이니셜라이저에서
제거한다. 총자산은 히어로가 말하고, 스크롤로 히어로가 밀려나면 §6 교대 규칙에 따라 하단
액세서리가 이어받으므로 화면에서 사라지지 않는다. 호출부는 `AllocationCard` 하나뿐이라
`Constants.totalLabel` 도 같이 지운다.

## 3. 소계 리스트

### 3.1 정렬

`NetWorthSummary.fundedBreakdown` 을 금액 내림차순으로 정렬한다. 금액이 같으면
`AssetCategory.allCases` 순서로 고정한다 — 정렬 결과가 매번 같아야 테스트할 수 있다.

이 한 곳이 도넛 섹터 순서와 리스트 순서를 동시에 고친다. `AllocationCard` 는 받은 배열을
그대로 도넛과 리스트에 넘기므로 카드 쪽에는 정렬 코드를 두지 않는다.

### 3.2 행 구조

한 줄에 다 넣던 것을 2단으로 나눈다.

```
[●] 국내주식              12,340,000원  34%  ›
    ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬░░░░░░░░░░░░░░░░
```

비중 막대:

- 높이 3pt `Capsule`
- 트랙 `surfaceSecondary`, 채움 `breakdown.category.color`
- 폭 = 트랙 폭 × `weight`. `GeometryReader` 한 겹으로 트랙 폭을 재서 곱한다
- `.accessibilityHidden(true)` — 행의 `accessibilityValue` 가 이미 "비중 34%"를 읽는다

첫 줄의 dot·이름·금액·퍼센트·chevron 구성은 그대로 둔다. 막대는 dot 아래가 아니라 dot 폭만큼
들여써서, 이름부터 chevron 앞까지의 폭을 100%로 잡는다.

DesignSystem 에 재사용 가능한 progress/weight 바가 없고, 다른 화면에서 쓸 곳도 없다.
막대는 `CategorySubtotalRow` 안에 피처 로컬로 둔다.

### 3.3 선택 연동

도넛에서 섹터를 고르면 해당 행이 `surfaceSecondary` 배경으로 강조된다. 탭의 결과가 홀 안에서만
일어나면 "리스트가 곧 범례"라는 구조가 화면에 드러나지 않는다.

`CategorySubtotalRow` 에 `isSelected: Bool` 을 더하고 `AllocationCard` 가
`selection == item.category` 를 넘긴다. 행 탭은 지금처럼 포트폴리오 탭 이동이고 바뀌지 않는다.
선택 상태는 `.accessibilityAddTraits(.isSelected)` 로도 노출한다.

## 4. 접근성

도넛은 VoiceOver 에서 **단일 요소**로 묶는다.

- label: `"자산군 비중"`
- value: 선택된 카테고리명 + 금액, 미선택이면 `"선택 안 함"`

커스텀 드래그 제스처는 VoiceOver 커서 아래에서 신뢰할 수 없다. 그래서 탭을 자산군별 금액에
닿는 **유일한 경로로 만들지 않는다**. 같은 정보를 아래 소계 행이 전부 읽어 주고, 그쪽이
VoiceOver 의 정식 경로다. 도넛에는 안내 힌트를 붙이지 않는다 — 실행할 수 없는 동작을 알리는
힌트는 소음이다.

## 5. 테스트

**단위 테스트 · `HannunDesignSystemTests`** — 히트 테스트 순수 함수

- 홀 안쪽 점은 `nil`
- 바깥 반지름 밖의 점은 `nil`
- 12시 직후의 점은 첫 슬라이스
- 슬라이스 경계 바로 앞뒤가 서로 다른 카테고리
- 각 사분면 대표점이 누적 비율과 맞는 카테고리

**단위 테스트 · `NetWorthFeatureTests`** — 정렬

- `fundedBreakdown` 이 금액 내림차순
- 금액이 같으면 `AssetCategory.allCases` 순서

**실기기 검증**

- 섹터 탭 → 선택, 같은 섹터 재탭 → 해제
- 스크럽 후 손을 떼도 선택 유지
- 홀 안쪽 탭이 선택을 바꾸지 않음
- 라이트 / 다크
- AX-XL 에서 홀 문구가 잘리지 않음
- VoiceOver 로 도넛 → 소계 행 순회

## 6. 변경 파일

| 파일 | 변경 |
|------|------|
| `Modules/DesignSystem/Sources/Components/DonutChart.swift` | 제스처 교체, 히트 테스트 추가, 중앙 홀 힌트, `totalLabel`·`total` 파라미터 제거 |
| `Modules/DesignSystem/Tests/DonutChartHitTestTests.swift` | 신규 — 히트 테스트 |
| `Features/NetWorth/Sources/ViewModels/NetWorthSummary.swift` | `fundedBreakdown` 내림차순 정렬 |
| `Features/NetWorth/Sources/Components/CategorySubtotalRow.swift` | 비중 막대, `isSelected` |
| `Features/NetWorth/Sources/Components/AllocationCard.swift` | 도넛 호출부 정리, 행에 선택 상태 전달 |
| `Features/NetWorth/Tests/NetWorthViewModelTests.swift` | 정렬 테스트 추가 |

## 7. 반영이 필요한 문서

구현 후 `docs/design/2026-07-27-ui-design-spec.md` §4.1 에 두 가지를 적는다.

- 중앙 홀이 미선택 상태에서 총액이 아니라 어포던스 힌트를 띄운다
- 소계 리스트는 금액 내림차순이며 각 행에 카테고리 색 비중 막대가 붙는다
