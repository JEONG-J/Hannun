# BottomAccessory 비주얼 재제안 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 확정 디자인 문서(`docs/design/2026-08-01-bottom-accessory-visual-redesign.md`)를 코드·프리뷰·스펙 문서에 반영한다.

**Architecture:** DesignSystem 공용 컴포넌트(FilterChip/AccessoryActionButton/AccessoryCaption/HannunTint/GlassRole)를 신규격으로 바꾸면 4개 Feature 액세서리가 대부분 따라온다. Feature 쪽은 슬롯 교환·아이콘 삭제·분기 확장만 손댄다. 게이트 7 검증 프리뷰는 DesignSystem DEBUG 전용 파일로 둔다.

**Tech Stack:** SwiftUI (iOS 26), Tuist. 외부 의존성 없음.

## Global Constraints

- 상태 관리는 `@Observable` 만 (CLAUDE.md 절대 규칙 1)
- 모듈 간 노출 타입 `public` (규칙 2) · Mock 은 `#if DEBUG` (규칙 3)
- 새 파일은 Xcode 헤더 블록 — 타깃명 `HannunDesignSystem`, `Created by euijjang97 on 8/1/26.` (규칙 6)
- 캡슐 배경·높이는 시스템이 그린다 — 컨테이너에 glass·높이 부여 금지 (§3.1)
- glass-on-glass 금지 · 터치 타깃 44pt(`.minimumTouchTarget`) 유지
- 고정 시각 높이 토큰 금지 — "라벨 + 세로 `spacingS` 패딩" + 바깥 `minHeight` 히트 프레임 (디자인 문서 원칙 4)
- 신규 raw 색상 금지 — wash 는 `HannunTint` 파생(12%/18%, RT 시 0.20/0.28)
- 커밋은 하지 않는다 — 작업 트리에 사용자 미커밋 변경이 섞여 있어 최종 보고 후 사용자가 결정
- 검증: 각 태스크 후 해당 모듈 빌드, 마지막에 `make generate && make inspect && make build-modules && make test-modules`

---

### Task 1: NetWorthScreen `.refreshable` (선행 이슈 — §10 결정 1 성립 조건)

**Files:**
- Modify: `Features/NetWorth/Sources/Views/NetWorthScreen.swift:33-42`

**Interfaces:**
- Consumes: `NetWorthViewModel.load() async` (기존)
- Produces: 순자산 탭 pull-to-refresh — 이후 Task 7 에서 `arrow.clockwise` 를 지워도 갱신 수단이 남는다

- [ ] **Step 1: ScrollView 에 refreshable 부착**

```swift
ScrollView {
    content
        .padding(.horizontal, .spacingL)
        .padding(.top, .spacingXS)
}
.background(Color.backgroundPrimary)
.refreshable { await viewModel.load() }
.navigationTitle(Constants.navigationTitle)
```

- [ ] **Step 2: 빌드 확인** — `make build-NetWorthFeature` (스킴명은 `make help` 로 확인)

### Task 2: HannunTint — wash 공개 진입점 + Reduce Transparency 알파 상향

**Files:**
- Modify: `Modules/DesignSystem/Sources/HannunTint.swift`

**Interfaces:**
- Produces: `static func wash(_ base: Color) -> HannunTint` (ShapeStyle 진입점) — Task 3·7 이 벤치마크 4색·neutral wash 에 사용
- resolve 가 `accessibilityReduceTransparency` 를 읽어 알파 0.12/0.18 → 0.20/0.28 상향

- [ ] **Step 1: resolve 에 RT 분기 + wash 진입점 추가**

```swift
public func resolve(in environment: EnvironmentValues) -> Color {
    let boosted = environment.accessibilityReduceTransparency
    let opacity = environment.colorScheme == .dark
        ? (boosted ? Constants.darkSchemeBoostedOpacity : Constants.darkSchemeOpacity)
        : (boosted ? Constants.lightSchemeBoostedOpacity : Constants.lightSchemeOpacity)
    return base.opacity(opacity)
}
```

```swift
public extension ShapeStyle where Self == HannunTint {
    static var brandTint: HannunTint { HannunTint(base: .brand) }
    static var gainTint: HannunTint { HannunTint(base: .gain) }
    static var lossTint: HannunTint { HannunTint(base: .loss) }
    static var neutralTint: HannunTint { HannunTint(base: .neutral) }

    /// 벤치마크 칩처럼 원색이 호출부에서 정해지는 wash. 카테고리 4색 확장 진입점이다
    /// (디자인 문서 §3 — 신규 raw 색 없이 파생 규칙만 확대).
    static func wash(_ base: Color) -> HannunTint { HannunTint(base: base) }
}

fileprivate enum Constants {
    static let lightSchemeOpacity: Double = 0.12
    static let darkSchemeOpacity: Double = 0.18
    /// Reduce Transparency — 유리 대신 불투명 면 위에 놓이므로 wash 를 진하게 민다 (§3).
    static let lightSchemeBoostedOpacity: Double = 0.20
    static let darkSchemeBoostedOpacity: Double = 0.28
}
```

- [ ] **Step 2: 빌드 확인** — DesignSystem 스킴 빌드

### Task 3: FilterChip `.accessory` 신규격 + ChipGroup 간격

**Files:**
- Modify: `Modules/DesignSystem/Sources/Components/FilterChip.swift`
- Modify: `Modules/DesignSystem/Sources/Components/ChipGroup.swift:61`

**Interfaces:**
- Consumes: `HannunTint.wash(_:)` (Task 2), `CategoryDot(color:)` (기존)
- Produces: `.accessory` 칩 — 비선택 무채움 Regular / 선택 wash + Semibold + `.isSelected` trait / tint 칩 상시 dot / 비활성 opacity 0.4 / RT·IC 스트로크 폴백. `CurrencyToggle`(tint nil)과 `BenchmarkAccessory`(tint 지정)가 자동으로 따라온다
- 시그니처 변경 없음 — `FilterChip(_:isSelected:isEnabled:tint:action:)` 유지

- [ ] **Step 1: FilterChip 본체 — 웨이트 분기·dot·trait·opacity**

`FilterChip` 에 `@Environment(\.chipAppearance)` 를 추가하고 body 를 교체:

```swift
@Environment(\.chipAppearance) private var appearance

public var body: some View {
    Button(action: action) {
        HStack(spacing: .spacingXS) {
            if showsLegendDot {
                CategoryDot(color: isSelected ? (tint ?? .brand) : .neutral)
                    .accessibilityHidden(true)
            }

            Text(title)
                .hannunFont(labelStyle)
                .lineLimit(1)
        }
        .modifier(ChipSurface(isSelected: isSelected, isEnabled: isEnabled, tint: tint))
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : Constants.disabledOpacity)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .hannunAnimation(.selection, value: isSelected)
}

/// 액세서리 비선택만 Regular — 웨이트가 선택 신호의 실제 부호화 채널이다 (디자인 문서 원칙 5).
private var labelStyle: HannunTextStyle {
    appearance == .accessory && !isSelected ? .caption : .pillLabel
}

/// 범례 색이 지정된 액세서리 칩은 dot 을 **상시** 배치한다 — 선택 전환 시 폭이 변하지 않아
/// 재배치 점프가 없다 (디자인 문서 §3).
private var showsLegendDot: Bool {
    appearance == .accessory && tint != nil
}
```

`Constants` 에 추가: `static let disabledOpacity: Double = 0.4` — `[게이트 대기 G6]` 주석.

- [ ] **Step 2: ChipSurface — accessory 표면 재작성 + content 경로 tint 제약**

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
@Environment(\.colorSchemeContrast) private var colorSchemeContrast
@Environment(\.colorScheme) private var colorScheme
```

accessory 분기 교체 (채움은 콘텐츠+세로 패딩, 44pt 는 바깥 히트 프레임):

```swift
@ViewBuilder
private func accessorySurface(_ content: Content) -> some View {
    content
        .foregroundStyle(accessoryLabelColor)
        .padding(.vertical, .spacingS)
        .padding(.horizontal, Constants.horizontalPadding)
        .background(accessoryBackground, in: .capsule)
        .overlay {
            if let boundary = accessoryBoundaryColor {
                Capsule().strokeBorder(boundary, lineWidth: Constants.boundaryLineWidth)
            }
        }
        .frame(minHeight: .minimumTouchTarget)
        .contentShape(.capsule)
}

/// 비선택은 무채움 — 시스템 캡슐의 유리가 배경이다. 선택만 원색 12%/18% wash (§3).
private var accessoryBackground: AnyShapeStyle {
    guard isSelected else { return AnyShapeStyle(Color.clear) }
    guard let tint else { return AnyShapeStyle(HannunTint.brandTint) }
    return AnyShapeStyle(HannunTint.wash(tint))
}

/// 투명도 감소·대비 증가에서는 "채움 없음"이 경계 상실이 되므로 스트로크로 경계를 복원한다.
private var accessoryBoundaryColor: Color? {
    guard reduceTransparency || colorSchemeContrast == .increased else { return nil }
    return isSelected ? (tint ?? .brand) : .separator
}

/// wash 위 라벨은 잉크(textPrimary)가 원칙 — 다크 brand on wash 는 3.25:1 로 AA 미달이다.
/// brand wash(통화 토글)만 라이트에 한해 brand 라벨을 유지한다 (§3.1 검증표).
private var accessoryLabelColor: Color {
    guard isSelected else { return .textSecondary }
    guard tint == nil else { return .textPrimary }
    return colorScheme == .dark ? .textPrimary : .brand
}
```

content 선택 경로에는 제약 주석 + DEBUG 검증 추가 (`selectedContentSurface` 앞):

```swift
// tint 는 액세서리 전용이다 — 콘텐츠 glass 위 원색 채움 + onBrand 는 카테고리색에서
// AA 미달(최악 2.15:1)이라 봉인한다 (디자인 문서 §6).
assert(tint == nil || appearance == .accessory, "FilterChip tint 는 .accessory 전용")
```

(assert 는 `body(content:)` 진입부에 둔다 — appearance 는 이미 환경으로 읽고 있다.)

- [ ] **Step 3: ChipGroup accessory 간격 4 → 8**

```swift
case .accessory:
    HStack(spacing: .spacingS) { content }
```

- [ ] **Step 4: FilterChip 프리뷰에 비활성·접근성 케이스 확인용 variant 유지, 빌드 확인**

### Task 4: AccessoryActionButton — primary 패딩 방식 + secondary 스트로크 캡슐

**Files:**
- Modify: `Modules/DesignSystem/Sources/Components/AccessoryActionButton.swift`

**Interfaces:**
- Produces: secondary = brand 1pt 스트로크 캡슐 + 라이트 `brand`/다크 `textPrimary` 라벨 + `brand` 아이콘 + `ViewThatFits` 아이콘 폴백 (§10 결정 8). primary 라벨형 = 시각 캡슐(라벨+세로 패딩) + 44pt 히트 프레임
- 시그니처 변경 없음

- [ ] **Step 1: labeledContent 재작성**

```swift
@Environment(\.colorScheme) private var colorScheme

@ViewBuilder
private func labeledContent(title: String) -> some View {
    switch style {
    case .primary:
        fullLabel(title: title)
            .foregroundStyle(Color.onBrand)
            .padding(.vertical, .spacingS)
            .padding(.horizontal, Constants.horizontalPadding)
            .hannunGlass(.accessoryPrimaryAction)
            .frame(minHeight: .minimumTouchTarget)
            .contentShape(.capsule)

    case .secondary:
        // 폭이 모자라면 라벨을 자르는 대신 아이콘만 남긴다 (디자인 문서 §3).
        ViewThatFits(in: .horizontal) {
            secondarySurface { fullLabel(title: title) }
            secondarySurface { iconOnlyLabel }
        }
    }
}

private func fullLabel(title: String) -> some View {
    HStack(spacing: .spacingXS) {
        if let systemImageName {
            Image(systemName: systemImageName)
                .imageScale(.small)
                .foregroundStyle(style == .secondary ? Color.brand : Color.onBrand)
        }

        Text(title)
            .lineLimit(1)
    }
    .hannunFont(.pillLabel)
}

@ViewBuilder
private var iconOnlyLabel: some View {
    if let systemImageName {
        Image(systemName: systemImageName)
            .imageScale(.small)
            .foregroundStyle(Color.brand)
            .hannunFont(.pillLabel)
    }
}

/// 스트로크가 "눌리는 것"의 경계를 색이 아닌 형태로 준다 — 다크 brand 라벨은 4.07:1 로
/// AA 미달이라 잉크 라벨 + brand 스트로크/아이콘 조합을 쓴다 (§3.1 검증표, §10 결정 8).
private func secondarySurface(@ViewBuilder content: () -> some View) -> some View {
    content()
        .foregroundStyle(colorScheme == .dark ? Color.textPrimary : Color.brand)
        .padding(.vertical, .spacingS)
        .padding(.horizontal, Constants.horizontalPadding)
        .overlay {
            Capsule().strokeBorder(Color.brand, lineWidth: Constants.strokeLineWidth)
        }
        .frame(minHeight: .minimumTouchTarget)
        .contentShape(.capsule)
}
```

`Constants` 에 `static let strokeLineWidth: CGFloat = 1` 추가. `circularContent` 는 유지.
(아이콘 `foregroundStyle` 이 surface 의 `foregroundStyle` 보다 안쪽이므로 아이콘 색이 이긴다.)

- [ ] **Step 2: 프리뷰 확인 후 빌드**

### Task 5: AccessoryCaption — 2톤 API + 장식 아이콘 제거

**Files:**
- Modify: `Modules/DesignSystem/Sources/Components/AccessoryCaption.swift`
- Modify: `Modules/DesignSystem/Sources/Components/BottomAccessory.swift` (프리뷰의 `systemImageName:` 호출 2곳 제거)
- Modify: `Modules/DesignSystem/Sources/Components/AccessoryActionButton.swift` (프리뷰의 `sparkles` 호출 제거)

**Interfaces:**
- Produces: `AccessoryCaption(_ text: String)` (1톤, 유지) + `AccessoryCaption(value: String, suffix: String)` (2톤 신설). `systemImageName:` 파라미터 **삭제** — 캡션 무아이콘 규칙 (§10 결정 6)
- Task 7 의 NetWorth/Journal 이 새 API 를 쓴다

- [ ] **Step 1: 2톤 구성으로 재작성**

```swift
/// 액세서리 캡슐 왼쪽에 놓는 보조 문구. 상태를 말하거나(갱신 시각) 다음 행동을 권한다(작성 힌트).
///
/// 아이콘은 받지 않는다 — 캡션 무아이콘이 규칙이다. 눌리지 않는 `arrow.clockwise` 같은
/// 어포던스 거짓말을 막고, "아이콘이 있으면 컨트롤"이라는 구분 신호를 지키기 위해서다.
///
/// 값(시각·수치)이 있는 문구는 2톤으로 쓴다 — 정보가치가 있는 값만 진하게, 부속어는 흐리게.
/// 단일 `Text` 연결이라 VoiceOver 는 한 요소로 읽고, 축소도 한 덩어리로 된다.
public struct AccessoryCaption: View {

    // MARK: - Property

    private let value: String?
    private let text: String

    // MARK: - Body

    public init(_ text: String) {
        value = nil
        self.text = text
    }

    /// - Parameters:
    ///   - value: 진하게 강조할 값 (예: "12:04"). tabular 숫자로 그린다.
    ///   - suffix: 뒤따르는 부속어 (예: "시세 기준").
    public init(value: String, suffix: String) {
        self.value = value
        text = suffix
    }

    public var body: some View {
        caption
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumScaleFactor)
            .accessibilityElement(children: .combine)
    }

    // MARK: - Function

    private var caption: Text {
        guard let value else {
            return Text(text)
                .font(.hannun(.caption))
                .foregroundStyle(Color.textSecondary)
        }
        return Text(value)
            .font(.hannun(.caption, tabularFigures: true).weight(.semibold))
            .foregroundStyle(Color.textPrimary)
            + Text(" \(text)")
            .font(.hannun(.caption))
            .foregroundStyle(Color.textSecondary)
    }
}
```

(`@Environment(\.accessoryLayout)` 은 더 이상 쓰지 않으므로 제거. 프리뷰도 새 API 로 교체.)

- [ ] **Step 2: 프리뷰 호출부 3곳 갱신** — `BottomAccessory.swift` 프리뷰의
  `AccessoryCaption("오후 12:04 시세 기준", systemImageName: "arrow.clockwise")` → `AccessoryCaption(value: "12:04", suffix: "시세 기준")`,
  `AccessoryCaption("오늘의 매매를 기록해보세요", systemImageName: "sparkles")` → `AccessoryCaption("오늘의 매매를 기록해보세요")`,
  `AccessoryActionButton.swift` 프리뷰도 동일. `BottomAccessory` doc 주석의 예시 코드도 새 API 로.

- [ ] **Step 3: DesignSystem 빌드 — 남은 `systemImageName:` 호출 컴파일 에러로 전수 확인**

### Task 6: GlassRole — accessoryControl 매핑 갱신

**Files:**
- Modify: `Modules/DesignSystem/Sources/GlassRole.swift`

**Interfaces:**
- Produces: `.accessoryControl` = 무채움(`Color.clear`) — "비선택 액세서리 컨트롤은 채움이 없다"를 role 표에도 반영. 실사용처는 프리뷰뿐이라 동작 영향 없음

- [ ] **Step 1: 매핑과 주석 교체**

```swift
/// 액세서리 내부 세그먼트·칩의 **비선택** 상태. 시스템 캡슐의 유리가 곧 배경이므로
/// 채움을 얹지 않는다 — 채움은 선택(`selectedAccessoryControl`)과 주 액션에만 있다.
/// 투명도 감소·대비 증가에서의 스트로크 폴백은 FilterChip 이 처리한다.
case accessoryControl
```

```swift
case .accessoryControl:
    .solid(AnyShapeStyle(Color.clear))
```

프리뷰(`systemAccessoryStandIn`)의 비선택 세그먼트가 무채움으로 그려지는지 확인.

- [ ] **Step 2: 빌드 확인**

### Task 7: Feature 액세서리 4종 갱신

**Files:**
- Modify: `Features/NetWorth/Sources/Components/NetWorthAccessory.swift`
- Modify: `Features/Portfolio/Sources/Components/PortfolioActionAccessory.swift`
- Modify: `Features/Performance/Sources/Components/BenchmarkAccessory.swift`
- Modify: `Features/Journal/Sources/Components/JournalComposeAccessory.swift`

**Interfaces:**
- Consumes: Task 2~5 의 신규 API (`AccessoryCaption(value:suffix:)`, secondary 스트로크, `HannunTint.wash`)

- [ ] **Step 1: NetWorthAccessory** — `refreshSymbolName` 상수·`arrow.clockwise` 제거,
  fresh 케이스를 2톤으로, 축약 분기를 AX 사이즈까지 확장:

```swift
case let .fresh(date):
    let time = date.formatted(date: .omitted, time: .shortened)
    if usesCompactCaption {
        AccessoryCaption(value: time, suffix: Constants.inlineCaptionSuffix)
    } else {
        AccessoryCaption(value: time, suffix: Constants.expandedCaptionSuffix)
    }
```

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

/// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 캡션을 숨기는 대신 줄인다 (§5).
private var usesCompactCaption: Bool {
    layout == .inline || dynamicTypeSize.isAccessibilitySize
}
```

Constants 를 suffix 문자열로 교체: `expandedCaptionSuffix = "시세 기준"`, `inlineCaptionSuffix = "기준"`.
`captionText(at:)` 함수는 삭제. StaleBadge 경로는 그대로 둔다 (§10 결정 3 — 형상 현행 유지).

- [ ] **Step 2: PortfolioActionAccessory — 슬롯 교환 + inline 신규격**

```swift
var body: some View {
    BottomAccessory {
        if collapsesToMenu {
            overflowMenu
        } else {
            AccessoryActionButton(
                Constants.cashFlowTitle,
                systemImageName: Constants.cashFlowSymbolName,
                style: .secondary,
                action: onShowCashFlow
            )
        }
    } trailing: {
        // 생성 액션은 항상 trailing — 4탭 공통 문법이다 (디자인 문서 원칙 2).
        if collapsesToMenu {
            AccessoryActionButton(
                systemImageName: Constants.addHoldingSymbolName,
                accessibilityLabel: Constants.addHoldingTitle,
                action: onAddHolding
            )
        } else {
            AccessoryActionButton(
                Constants.addHoldingTitle,
                systemImageName: Constants.addHoldingSymbolName,
                action: onAddHolding
            )
        }
    }
}
```

overflow 메뉴 라벨의 원 배경을 저채도 wash 로 (§10 결정 4, `[게이트 대기 G5]`):

```swift
/// 유일 진입점이라 시각적 바닥은 유지하되, 불투명 슬래브 대신 저채도 wash 를 쓴다.
/// 게이트 G5(3초 내 발견) 실패 시 surfaceSecondary 로 되돌린다 (§10 결정 4).
private var menuLabel: some View {
    Image(systemName: Constants.overflowSymbolName)
        .hannunFont(.rowTitle)
        .foregroundStyle(Color.textSecondary)
        .frame(width: .minimumTouchTarget, height: .minimumTouchTarget)
        .background(HannunTint.neutralTint, in: .circle)
}
```

- [ ] **Step 3: BenchmarkAccessory — 접힘 조건 확장 + 메뉴 라벨 신규격**

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

/// 탭바 최소화·AX 사이즈·칩 초과 시 Menu 로 접는다. 기존 개수 조건은 폭 초과를 받지
/// 못하므로(4 > 4 는 항상 거짓) 타입 사이즈 조건을 더한다 (디자인 문서 §3.2·§4.3).
private var collapsesToMenu: Bool {
    layout == .inline
        || dynamicTypeSize.isAccessibilitySize
        || BenchmarkIndex.allCases.count > Constants.maximumChipCount
}
```

메뉴 라벨 — 원색 채움 + `onBrand` 폐기, wash + dot + 잉크 (§4.3):

```swift
private var menuLabel: some View {
    HStack(spacing: .spacingXS) {
        if let selected = viewModel.selectedBenchmark {
            CategoryDot(color: selected.lineColor)
                .accessibilityHidden(true)
        }

        Text(viewModel.selectedBenchmark?.title ?? Constants.emptySelectionTitle)
            .hannunFont(.pillLabel)
            .lineLimit(1)
            .foregroundStyle(menuLabelColor)

        Image(systemName: Constants.chevronSymbolName)
            .imageScale(.small)
            .foregroundStyle(Color.textSecondary)
    }
    .padding(.vertical, .spacingS)
    .padding(.horizontal, Constants.labelHorizontalPadding)
    .background(menuLabelBackground, in: .capsule)
    .frame(minHeight: .minimumTouchTarget)
    .contentShape(.capsule)
}

private var menuLabelBackground: AnyShapeStyle {
    guard let color = viewModel.selectedBenchmark?.lineColor else {
        return AnyShapeStyle(Color.clear)
    }
    return AnyShapeStyle(HannunTint.wash(color))
}

private var menuLabelColor: Color {
    viewModel.selectedBenchmark == nil ? .textSecondary : .textPrimary
}
```

`import HannunDesignSystem` 은 이미 있음. 칩 쪽(`chips`)은 FilterChip 신규격이 자동 반영 — 변경 없음.

- [ ] **Step 4: JournalComposeAccessory — sparkles 제거 + 주 액션 라벨 캡슐(§10 결정 2)**

```swift
var body: some View {
    BottomAccessory {
        AccessoryCaption(hintText)
    } trailing: {
        // 생성 = 우측 brand 캡슐 문법 (§10 결정 2). 축약에서는 아이콘 원형으로 줄인다.
        if usesCompactAction {
            AccessoryActionButton(
                systemImageName: Constants.composeSymbolName,
                accessibilityLabel: Constants.composeAccessibilityLabel,
                action: action
            )
        } else {
            AccessoryActionButton(
                Constants.composeTitle,
                systemImageName: Constants.composeSymbolName,
                action: action
            )
        }
    }
}

@Environment(\.dynamicTypeSize) private var dynamicTypeSize

private var usesCompactAction: Bool { layout == .inline }

/// 축약 문구는 inline 만이 아니라 AX 사이즈에서도 쓴다 — 캡션을 숨기는 대신 줄인다 (§5).
private var hintText: String {
    layout == .inline || dynamicTypeSize.isAccessibilitySize
        ? Constants.inlineHintText
        : Constants.hintText
}
```

Constants: `hintSymbolName` 삭제, `composeTitle = "작성"` 추가. 라벨형 버튼의 VoiceOver 는
title("작성")이지만 원형과 동일 의미가 되도록 `composeAccessibilityLabel` 은 원형 쪽에 유지.

- [ ] **Step 5: Feature 4종 빌드 확인**

### Task 8: 게이트 7 검증 프리뷰 (DesignSystem DEBUG)

**Files:**
- Create: `Modules/DesignSystem/Sources/Components/AccessoryGatePreview.swift` (파일 전체 `#if DEBUG`)

**Interfaces:**
- Consumes: BottomAccessory/AccessoryCaption/AccessoryActionButton/FilterChip/ChipGroup/CurrencyToggle/StaleBadge
- Produces: 게이트 7 촬영용 매트릭스 프리뷰 — 4탭 대역 × 정상/선택/비활성/stale, 라이트/다크 Preview 2종. Feature 를 import 할 수 없으므로 DS 컴포넌트만으로 각 탭 상태를 재현한다

- [ ] **Step 1: 파일 생성** — Xcode 헤더(`HannunDesignSystem`, 8/1/26) + `#if DEBUG` 전체 감싼
  `AccessoryGatePreview` 뷰. 구성: `BottomAccessoryPreview` 의 standIn 패턴을 재사용해
  ① 순자산(2톤 캡션+토글 / 로딩 / stale+토글), ② 포트폴리오(스트로크 보조+brand 주 액션 /
  inline: wash 원 Menu+원형), ③ 성과(dot 칩 4개 — 선택/비선택/비활성 혼합 / inline 메뉴 라벨),
  ④ 매매일지(힌트+작성 캡슐 / inline 원형) 를 세로로 나열. `#Preview` 4개: 라이트 / 다크 /
  라이트·`.environment(\.accessibilityReduceTransparency, true)` 대역(가능 범위) / inline 강제.
  각 행에 게이트 항목 번호(G1~G8)를 캡션으로 붙인다.

- [ ] **Step 2: `make generate`** (새 파일 등록) 후 DesignSystem 빌드

### Task 9: 문서 개정 (디자인 문서 §7 목록)

**Files:**
- Modify: `docs/design/2026-07-27-ui-design-spec.md` — §2.1 brand 라벨 실측 각주 / §2.2 비활성 opacity 규칙 신설 / §2.4 표 2행(액세서리 칩·일지 버튼) / §3.1 내부 컨트롤 규정·탭별 내용 표·overflow 바닥 주석 / §4.3 선택 칩 wash+dot·"최대 4개" 개수+폭 병기 / §4.4 라벨 캡슐 / §6.3 RT 분기 / 서문 개정 이력 1줄
- Modify: `docs/claude/design-system.md` — Glass variant 표의 액세서리 행(비선택 무채움 + 폴백)
- Modify: `docs/design/2026-07-31-pencil-design-reference.md` — 액세서리 절(§6.1~6.4 서술·§7 inline 표)에 "구현이 2026-08-01 재제안으로 시안과 다름 — `hannun.pen` 갱신 대기" 주석

**Interfaces:**
- Consumes: `docs/design/2026-08-01-bottom-accessory-visual-redesign.md` (확정 규격의 원본)

- [ ] **Step 1: 각 문서의 해당 절을 Read 로 열어 확정 규격으로 갱신** — 새 규격 수치는 디자인
  문서 §3(공통 규격)·§3.1(검증표)에서 그대로 옮긴다. 스펙이 원본이므로 코드 서술과 어긋나는
  문장을 남기지 않는다.
- [ ] **Step 2: `hannun.pen` 은 Pencil 데스크톱 앱 부재로 이번에 갱신 불가** — pencil-reference
  주석으로 대기 상태를 명시 (후속 작업).

### Task 10: 최종 검증

- [ ] **Step 1:** `make generate && make inspect` — 새 파일 등록 + 암묵 의존성 검사
- [ ] **Step 2:** `make build-modules` — 전 모듈 빌드
- [ ] **Step 3:** `make test-modules` — 기존 테스트 회귀 확인 (NetWorthViewModelTests·PerformanceViewModelTests 등)
- [ ] **Step 4:** 결과 보고 — 커밋은 사용자 결정 대기 (작업 트리에 세션 이전 미커밋 변경 존재)
