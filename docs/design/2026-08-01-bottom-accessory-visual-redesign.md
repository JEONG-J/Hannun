# 탭바 하단 액세서리 비주얼 재제안 — "유리를 다시 유리답게"

- 작성일: 2026-08-01
- 상태: **확정** (단, `[게이트 대기]` 표기 항목은 §9 실기기 검증 통과 후 잠금 해제)
- 범위: `tabViewBottomAccessory` 내용물의 비주얼만. 등록 구조(TabAccessoryHost)·캡슐 재질·높이는 불변(§3.1 계약).
- 이력: haeun-designer 초안 → soyeon-ui-review BLOCK → 개정판 → 재심 APPROVE WITH CONDITIONS
  → 재심 조건 5건 반영 + junho-pm 의사결정 7건 채택(§10)으로 확정.

> **부분 대체 (2026-08-02).** 액세서리의 **구성 원리**가 "툴바"에서 "상태 한 줄 + 컨트롤 하나의
> 단일 스트립"으로 바뀌었다 — `2026-08-02-bottom-accessory-single-view-redesign.md`.
>
> - **대체됨**: §4 탭별 스펙 전체(특히 §4.2 액션 2개, §4.3 벤치마크 칩 4개), §3.2 폭 예산,
>   §9 게이트 중 G5·G7(대상 소멸), §5 의 2행 재배치·`lineLimit(2)` 폴백
> - **유효**: §2 개선 원칙, §3 공통 규격 토큰 값, §3.1 다크 대비 검증표, §5 나머지 접근성 규격,
>   §10 결정 기록 — 이것들이 새 문서의 비주얼 문법 기반이다
>
> 아래 §4 를 구현 근거로 삼지 말 것.

## 1. 현황 진단

1. **비선택 칩의 슬래브 채움이 캡슐을 벽돌로 만든다.** 이미 잘 지켜진 부분은 분명히 하자 —
   보조 액션 버튼은 채움이 없고(`AccessoryActionButton.swift:94-100`), 통화 토글의 선택 상태는
   이미 `brandTint` wash 다(`FilterChip.swift:147-151`). 문제는 **비선택** 칩이다: `.accessory`
   표면이 비선택에도 `surfaceSecondary` 를 깔고 `minHeight 44` 채움을 강제해
   (`FilterChip.swift:139-151`), 56pt 시스템 캡슐 안에서 상하 6pt만 남긴다.
   `03-performance-tab.png`가 대표: 회색 슬래브 3개 + 원색 슬래브 1개가 붙어 세그먼트 바가 되고,
   시스템이 그려 주는 Liquid Glass 재질이 그 뒤로 사라진다.
2. **주 액션의 앵커가 탭마다 다르다.** 포트폴리오는 brand 채움 주 액션이 **왼쪽**
   (`PortfolioActionAccessory.swift:26-31`), 매매일지는 brand 원형 주 액션이 **오른쪽**
   (`JournalComposeAccessory.swift:27-33`). 같은 의미(생성)의 자리와 모양(캡슐 vs 원)이
   탭마다 바뀐다.
3. **보조 액션에 어포던스가 없다.** "입출금 기록"은 13pt 라벨뿐이고, 같은 자리의
   `AccessoryCaption`(13pt Regular `textSecondary`)과 웨이트·명도 한 단계 차이라 정적 문구와
   컨트롤이 구분되지 않는다.
4. **선택 벤치마크 칩의 대비가 AA 미달이다.** 선택 칩을 카테고리 원색으로 가득 채우고
   `onBrand`(라이트=흰색) 라벨을 얹는데(`FilterChip.swift:147-156`), 라이트 실측: 흰 라벨 on
   `categoryCrypto #F59E0B` ≈ **2.15:1**(최악), on `categoryForeign #06AED4` ≈ 2.6:1, on
   `categoryEtf #A855F7` ≈ 4.0:1 — 13pt Semibold 는 대형 텍스트가 아니므로 전부 4.5:1 미달.
   `onBrand` 대비 논증(스펙 §2.1)은 brand 인디고에만 성립하고 벤치마크 4색으로 일반화되지
   않는다. `.inline` 메뉴 라벨도 같은 구조다(`BenchmarkAccessory.swift:102-111`).
5. **캡션 위계가 평탄하고 아이콘이 어포던스를 속인다.** "오후 12:04 시세 기준"에서 정보가치는
   시각(12:04)에 있는데 전체가 한 톤이고, 앞의 `arrow.clockwise`는 "누르면 갱신"을 뜻하는
   글리프인데 눌리지 않는다(`NetWorthAccessory.swift:53-56`). `sparkles`도 정보 없이 폭만
   차지한다.
6. **선택 신호의 부호화 채널이 색 하나뿐이다.** 선택/비선택 라벨이 둘 다 `pillLabel` 13pt
   Semibold 라 웨이트가 신호를 싣지 않고(`FilterChip.swift:48-60`),
   `.accessibilityAddTraits(.isSelected)` 도 없다 — `GranularityToggle.swift:71` 이 이미 쓰는
   패턴인데 액세서리 칩만 빠져 있다.

## 2. 개선 원칙

1. **One Fill Rule.** 캡슐 하나에 **고채도 채움**(brand·카테고리 원색 solid)은 최대 1개 —
   주 액션 또는 선택 칩. 저채도 요소(tint wash, 소형 wash 원)는 채움 수에 세지 않는다.
2. **주 액션은 항상 trailing.** 생성 액션은 4탭 모두 오른쪽의 brand 캡슐. 왼쪽은 정보(캡션)·
   보조 액션의 자리이며, 폭이 모자라면 왼쪽이 먼저 양보하되 **보조 액션은 잘리는 대신
   아이콘 폴백으로 축약**한다(§3).
3. **값 우선 타이포.** 캡션은 2톤 — 값(시각·수치)은 13pt Semibold tabular + `textPrimary`,
   부속어는 13pt Regular + `textSecondary`. 단일 `Text` 연결로 VoiceOver 한 요소를 유지한다.
4. **채움은 콘텐츠를 따라가고, 44pt는 히트 프레임이 보장한다.** 채움 캡슐의 시각 크기는
   "라벨 + 세로 패딩 `spacingS` 8"이 정하고(Dynamic Type 추종), 터치 타깃은 바깥의
   `minHeight(.minimumTouchTarget)` 프레임 + `contentShape` 확장으로 44pt 를 유지한다.
   고정 높이 토큰은 두지 않는다.
5. **색 = 의미, 단 색 혼자는 안 된다.** brand 는 행동·선택, 카테고리색은 범례, 그 외 무채색.
   선택 신호는 색(wash·dot) + 웨이트(Regular→Semibold) + `.isSelected` trait 로 **삼중
   부호화**하고, 텍스트 4.5:1 / 아이콘·그래픽 3:1 을 라이트·다크 모두 검증한다.

## 3. 공통 규격

| 항목 | 토큰/값 | 비고 |
|---|---|---|
| 슬롯 안쪽 여백 (expanded / inline) | **6 / 2 — §3.1 확정값·현행 유지** | 초안의 16/12 제안 철회 |
| 슬롯 간 최소 간격 | `spacingS` 8 | 현행 유지 |
| 채움 컨트롤 구조 | 안쪽: 라벨 + 세로 `spacingS` 8 패딩에 채움 → 바깥: `minHeight(.minimumTouchTarget)` + `contentShape` | 기본 타입에서 시각 높이 ≈ 34pt(footnote 행높이 ≈18 + 8×2), Dynamic Type 추종. 고정 토큰 없음 |
| 칩 내부 가로 패딩 | 14 (현행 유지) | 공유 상수라 콘텐츠 칩까지 번지므로 12 축소안 철회 |
| 칩 간격 | `spacingS` 8 | 히트 영역 오인 방지 |
| 캡션 — 값 / 부속어 | 13 Semibold tabular `textPrimary` / `caption` 13 Regular `textSecondary` | 단일 `Text` 연결 + `accessibilityElement(children: .combine)` 유지 |
| 주 액션 (라벨형) | `brand` 채움 · `onBrand` `pillLabel` · 아이콘 `imageScale(.small)` | `GlassRole.accessoryPrimaryAction` 유지 |
| 보조 액션 | **`brand` 1pt 스트로크 캡슐** · 라이트 라벨 `brand` 13 Semibold / 다크 라벨 `textPrimary` 13 Semibold · 아이콘 `brand` | 스트로크는 그래픽 3:1 기준 통과(다크 4.07:1). 라이트/다크 어포던스 강도 대칭, §5 IC 폴백과 수단 통일. 다크 `brand` **라벨**은 4.07:1 로 텍스트 AA 미달이라 잉크로 대체 (§10 결정 8) |
| 보조 액션 폭 대응 | `ViewThatFits`: 아이콘+라벨 → **아이콘 단독**(accessibilityLabel 유지) | 라벨이 잘리는 상태를 만들지 않는다 |
| 선택 상태 | 해당 색 tint wash + 라벨 `pillLabel` 13 **Semibold** + `.accessibilityAddTraits(.isSelected)` **필수** | 선례: `GranularityToggle.swift:71` |
| 비선택 상태 | 채움 없음 · 라벨 `caption` 13 **Regular** `textSecondary` `[게이트 대기 G1·G2]` | 웨이트가 실제 부호화 채널이 된다 |
| 비활성 상태 | 비선택과 동일 + 전체 `opacity 0.4` + disabled `[게이트 대기 G6]` | `neutral` 은 `textSecondary` 와 동일 hex(#6B7280/#9AA1AE)라 구분 채널이 못 된다. 0.4 는 제안값 — G6 에서 0.5~0.6 상향 후보와 함께 확정 |
| 투명도·대비 폴백 | `reduceTransparency` 또는 `colorSchemeContrast == .increased` 시: 비선택 칩에 `separator` 1pt 스트로크 캡슐, 선택 칩에 해당 원색 1pt 스트로크 승격 | "채움 없음"이 경계 상실로 이어지지 않게 하는 필수 분기 |
| wash 파생 | `HannunTint` 규칙(원색 12%/18%)을 **벤치마크 4색**(`categoryDomestic/Foreign/Etf/Crypto`)으로 확장. `reduceTransparency` 시 알파 상향 분기(라이트 0.20 / 다크 0.28 제안) `[게이트 대기 G2]` | 신규 raw 색상 없음, 파생 규칙 확대. `HannunTint` 공개 API 신설 필요(§6) |
| 범례 dot | 기존 `CategoryDot(color:)` 재사용(8pt). **모든 벤치마크 칩에 상시 배치** — 선택 = 카테고리 원색, 비선택 = `neutral` | 선택 시 폭이 변하지 않아 재배치 점프가 없다. dot 은 `accessibilityHidden`. 비선택 dot 원색 40% 안은 G1 관찰 후보 |
| 캡션 아이콘 | **없음** — 상태를 말하는 아이콘(경고 등)만 허용 | 아이콘 유무 자체가 "컨트롤 vs 문구" 신호가 된다 (§10 결정 6) |

### 3.1 다크 모드 대비 검증표

유리 배후를 `surfacePrimary` 다크 `#1D2029` 근사로 가정한 계산값 — 유리 위 실제 수치는 배후
콘텐츠에 따라 변동하므로 §9 게이트에서 최악 배경 스냅샷으로 재검증한다.

| 조합 | 대비 | 판정 |
|---|---|---|
| `onBrand #0A0C12` on `brand #6E6CFF` | ≈ 4.9:1 | 텍스트 AA 통과 |
| `textPrimary #F2F4F8` on 유리 | ≈ 14.8:1 | 통과 |
| `textSecondary #9AA1AE` on 유리 | ≈ 6.3:1 | 통과 |
| `brand #6E6CFF` **라벨** on 유리 | ≈ **4.07:1** | 텍스트 AA **미달** → 다크 라벨은 `textPrimary` 로 대체 |
| `brand #6E6CFF` **스트로크/아이콘** on 유리 | ≈ 4.07:1 | 그래픽 3:1 통과 |
| `brand #6E6CFF` on `brandTint` wash(다크) | ≈ **3.25:1** | 텍스트 AA **미달** → 통화 토글 다크 선택 라벨은 `textPrimary` 로 통일 (§4.1) |
| 선택 dot 다크 변형 `#22C6E6` / `#FBBF24` on 유리 | ≈ 8.0 / 9.8:1 | 통과 |

라이트의 dot 최악치는 `#F59E0B` ≈ **2.15:1** 로 3:1 미달 — dot 은 단독 신호가 아니라 보조
단서이며, 선택 상태는 wash + 웨이트 + `.isSelected` trait 로 중복 부호화되어 있으므로
허용한다(WCAG 1.4.11 중복 그래픽 면제).

### 3.2 성과 탭 폭 예산 `[게이트 대기 G7]`

개정판의 추정 예산(라벨 근사 157 + 패딩 112 + dot 48 + 간격 24 = 341pt ≤ 346pt)은 **대형
iPhone(캡슐 안쪽 ≈358pt) 가정 + 추정 글리프 폭** 위의 계산이다. 화면 폭 375pt 기기에서는
가용폭이 ≈328pt 로 줄어 기본 타입에서도 넘칠 수 있다.

- 기준선은 **375pt 기기**로 잡고, 글리프 폭은 구현 시 `#Preview` 스냅샷으로 실측해 재작성한다.
- 초과 시 완충 수단(우선순위 순): dot–라벨 간격 4→2 → 라벨 축약("S&P500"→"S&P") →
  비선택 dot 을 투명 플레이스홀더로 대체(폭 고정 유지).
- **현행 접힘 규칙은 폭을 받아주지 못한다** — `BenchmarkAccessory.swift:43-45` 의 접힘 조건은
  `BenchmarkIndex.allCases.count(4) > maximumChipCount(4)` 라는 항상-거짓 상수 비교 +
  `layout == .inline` 뿐이라 폭·글자 크기를 보지 않는다. 폭/타입 기반 접힘 추가가 §6 변경
  목록에 포함된 이유다.

## 4. 상태·변형별 스펙

### 4.1 순자산 (NetWorthAccessory)

- **expanded**: 좌 — 2톤 캡션 "**12:04** 시세 기준"(시각 = Semibold tabular `textPrimary`,
  나머지 = Regular `textSecondary`, 단일 Text 연결). `arrow.clockwise` **삭제** — 캡션은 정적으로
  확정한다(§10 결정 1). **선행 조건: `NetWorthScreen` 에 `.refreshable` 추가** — 현재 순자산
  탭에는 pull-to-refresh 가 없어(진입 로드뿐) 아이콘을 지우면 갱신 수단이 0이 된다. 같은
  릴리즈의 선행 이슈로 묶는다. 우 — `CurrencyToggle`: 선택 = `brandTint` wash + 라벨
  **라이트 `brand` / 다크 `textPrimary`** Semibold(다크 `brand` on wash 3.25:1 AA 미달 — §3.1 표,
  벤치마크 칩과 같은 "wash 위 라벨은 잉크" 규칙으로 통일), 비선택 = 채움 제거 + `textSecondary`
  Regular, 폴백 시 스트로크. 고채도 fill: 0.
- **inline**: 캡션 "12:04 기준"(현행 문구), 토글 동일 구조.
- **로딩**: "시세 불러오는 중" 전체 Regular `textSecondary`.
- **stale**: 캡션 자리를 `StaleBadge` 가 치환 — **형상·색·문구 모두 현행 유지**(`radiusS`
  라운드 사각, `neutralTint`, §10 결정 3: "각진 것 = 정보, 캡슐 = 컨트롤"이라는 비색 채널
  보존). 토글은 계속 동작. 배지는 어떤 상태에서도 숨기지 않는다(§5).

### 4.2 포트폴리오 (PortfolioActionAccessory)

- **expanded**: **슬롯 교환**(진단 2) — 좌: "입출금 기록" 보조 액션(§3 규격: brand 1pt
  스트로크 캡슐 + 라이트 brand/다크 textPrimary 라벨 + brand 아이콘, `ViewThatFits` 아이콘
  폴백, 히트 44). 우: "종목 추가" 주 액션(brand 캡슐, `plus` + 라벨). 고채도 fill: 1.
- **inline**: 좌 — overflow `Menu`("입출금 기록" 수납, 접힘 방향은 §3.1 불변 조건 그대로
  액세서리 안). 라벨은 `ellipsis` + **`neutralTint` wash 원**(§10 결정 4 — 유일 진입점의
  발견성과 슬래브 제거의 절충) `[게이트 대기 G5 — 실패 시 surfaceSecondary 원 자동 복귀]`.
  우 — 주 액션 아이콘 원형 축약(`plus`, 히트 44).

### 4.3 성과 (BenchmarkAccessory)

- **expanded**: 칩 4개 + **상시 dot**(`CategoryDot(color:)` 재사용, 좌측 8pt, 라벨과 4pt 간격).
  **비선택** = dot `neutral` + 라벨 Regular `textSecondary`, 채움 없음. **선택** = dot 카테고리
  원색 + 해당 원색 wash 캡슐 + 라벨 `textPrimary` Semibold + `.isSelected` trait. 원색 가득
  채움 + 흰 라벨(진단 4) 폐기. **비활성** = 비선택 + opacity 0.4 + disabled(값은 G6 확정).
  Increase Contrast 시 선택 칩에 원색 1pt 스트로크 승격. 고채도 fill: 0.
- **inline**: Menu 라벨 = 선택 벤치마크의 wash 캡슐 + 원색 dot + 이름 `textPrimary` Semibold +
  `chevron.down` small `textSecondary`. 선택 없음 = "벤치마크" Regular `textSecondary`, 채움
  없음. 현행 원색 채움 + `onBrand` 폐기.
- **접힘**: 현행 개수 기반 조건에 **폭/타입 기반 조건을 추가**한다 —
  `dynamicTypeSize >= .accessibility1` 시 Menu 로 전환하거나 `ViewThatFits { 칩 4개; Menu }` 로
  폭 기반 전환(§3.2). 스펙 §4.3 "최대 4개" 조항도 개수+폭 병기로 개정한다(§7).
- **다크**: dot·wash 는 카테고리 다크 변형으로 자동 전환(§3.1 검증표).

### 4.4 매매일지 (JournalComposeAccessory)

- **expanded**: 좌 — 힌트 "오늘의 매매를 기록해보세요" 전체 Regular `textSecondary`,
  `sparkles` 삭제. 우 — 주 액션 **`pencil.line` + "작성" brand 라벨 캡슐**(§10 결정 2 —
  4탭 "생성 = 우측 brand 캡슐" 문법 완성. 스펙 §4.4의 FAB 폐지 근거가 이미 라벨형을
  가리킨다). 고채도 fill: 1.
- **inline**: 힌트 "매매 기록"(현행), 버튼 아이콘 원형 축약(접근성 라벨 "일지 작성" 유지).

## 5. 접근성 규격

- **Dynamic Type**: 액세서리 콘텐츠는 Dynamic Type 을 추종한다(원칙 4 — 채움이 콘텐츠를
  따라가므로 자연 확장). **AX 사이즈에서 `.inline` 강제 전환·캡션 숨김은 하지 않는다** —
  캡션은 stale 경고(순자산)와 빈 상태 CTA(매매일지)를 담는 유일한 자리다. 대응 3단계:
  1. **문구 단축** — 각 탭의 inline 축약 문구("12:04 기준"·"매매 기록")를 AX 사이즈에서
     재사용한다. `NetWorthAccessory`·`JournalComposeAccessory` 의 분기 조건을
     `layout == .inline || dynamicTypeSize.isAccessibilitySize` 로 확장(§6).
  2. **[조건부] 2행 재배치** — `ViewThatFits` 로 1행 → 2행(캡션 위/컨트롤 아래). 시스템
     컨테이너 높이가 콘텐츠에 맞춰 자라는지 불확실하므로 **구현 검증 후 채택**.
  3. **2행 불가 시 폴백** — 캡션 `lineLimit(2)` 허용 또는 우측 컨트롤 아이콘 폴백.
  칩 폭 초과는 §4.3 의 폭/타입 기반 접힘이 받는다.
- **터치 타깃**: 모든 컨트롤 44pt — `minHeight(.minimumTouchTarget)` 히트 프레임 방식.
- **VoiceOver**:
  - 선택형 컨트롤(벤치마크 칩·통화 토글)은 `.accessibilityAddTraits(.isSelected)` **필수**.
  - 2톤 캡션은 단일 `Text` 연결 + `accessibilityElement(children: .combine)` 로 한 요소.
  - 보조 액션은 `Button` 래핑으로 `.isButton` trait 보장.
  - 범례 dot 은 `accessibilityHidden` — 선택 정보는 trait 와 라벨이 전달.
  - `CurrencyToggle` 컨테이너 라벨 "표시 통화" 유지. 비활성 칩은 disabled 상태를 명시.
- **Reduce Transparency / Increase Contrast**: §3 폴백 규격 — 비선택 `separator` 스트로크,
  선택 원색 스트로크 승격, `HannunTint` 알파 상향 분기. (현재 리포지토리에
  `reduceTransparency` 참조 0건 — 스펙 §6.3 에 액세서리 내부 컨트롤 분기 명문화 필요, §7.)

## 6. 변경 대상 API 목록

신규 토큰은 없다(초안의 `accessoryControlHeight`/`Inline`/`legendDotSize` 전부 철회).

| 파일 | 변경 요지 |
|---|---|
| `Modules/DesignSystem/Sources/Components/FilterChip.swift` | `.accessory` 표면: 비선택 채움 제거(+RT/IC 스트로크 폴백), 선택 wash + 원색 dot 상시 배치, 웨이트 Regular/Semibold 분기, `.isSelected` trait, 비활성 opacity. **`tint:` 는 `.accessory` appearance 전용으로 제약**(콘텐츠 경로의 원색 채움+`onBrand` 재현 차단) |
| `Modules/DesignSystem/Sources/Components/ChipGroup.swift` | `.accessory` 칩 간격 `spacingXS` 4 → `spacingS` 8 |
| `Modules/DesignSystem/Sources/Components/AccessoryActionButton.swift` | secondary 스타일 재정의: brand 1pt 스트로크 캡슐 + 라이트 brand/다크 textPrimary 라벨 + brand 아이콘 필수, `ViewThatFits` 아이콘 폴백, 채움을 라벨+세로 패딩 방식으로 |
| `Modules/DesignSystem/Sources/Components/AccessoryCaption.swift` | 2톤 구성(단일 Text 연결), 아이콘 파라미터 제거 또는 상태 아이콘 전용 제약, `.combine` 유지 |
| `Modules/DesignSystem/Sources/Components/CurrencyToggle.swift` | FilterChip 재사용이므로 대부분 자동 반영 + 다크 선택 라벨 `textPrimary` 분기 |
| `Modules/DesignSystem/Sources/HannunTint.swift` | **공개 API 신설**: 벤치마크 4색 wash 진입점 + `reduceTransparency` 알파 상향 분기 |
| `Modules/DesignSystem/Sources/GlassRole.swift` | `accessoryControl` 매핑: `surfaceSecondary` 채움 → 채움 없음/스트로크 폴백. `selectedAccessoryControl` wash 유지 |
| `Modules/DesignSystem/Sources/Components/StaleBadge.swift` | **변경 없음** (§10 결정 3 — 현행 radiusS 유지) |
| `Modules/DesignSystem/Sources/Components/BottomAccessory.swift` | 여백 6/2 유지. **[조건부]** §5 의 2행 재배치가 검증되면 `ViewThatFits` 폴백 추가. 프리뷰 stand-in 은 새 모습 반영 |
| `Features/NetWorth/Sources/Views/NetWorthScreen.swift` | **선행 이슈**: `.refreshable` 추가(§10 결정 1 의 성립 조건) |
| `Features/NetWorth/Sources/Components/NetWorthAccessory.swift` | 캡션 2톤·`arrow.clockwise` 제거, 축약 분기 `layout == .inline \|\| dynamicTypeSize.isAccessibilitySize` 확장 |
| `Features/Portfolio/Sources/Components/PortfolioActionAccessory.swift` | 슬롯 교환, 보조 액션 신규격, inline 메뉴 라벨 `neutralTint` wash 원 |
| `Features/Performance/Sources/Components/BenchmarkAccessory.swift` | 칩·inline 메뉴 라벨 신규격(dot + wash + textPrimary), **폭/타입 기반 접힘 조건 추가**(§3.2·§4.3) |
| `Features/Journal/Sources/Components/JournalComposeAccessory.swift` | 힌트 아이콘 제거, 주 액션 라벨 캡슐화, 축약 분기 확장 |

별도 이슈로 분리(액세서리 범위 밖): `neutral` 토큰 정리 — `textSecondary` 와 값이 완전히
동일해 존재 이유가 없다(통합 또는 값 재정의).

## 7. 개정 필요 문서·시안

이 문서가 채택 기준이므로 아래를 코드보다 먼저 또는 함께 갱신한다.

- `docs/design/2026-07-27-ui-design-spec.md`
  - §2.1 — brand 라벨 제약 문단에 실측 각주: "다크 유리·다크 wash 위 brand 라벨은 AA 미달
    (4.07 / 3.25:1) — 라벨로 쓰지 않는다"
  - §2.2 — "비활성 = 기준 색 + opacity 감쇠" 규칙 신설, §4.3 비활성 표시와 상호 참조
  - §2.4 — "액세서리 내부 세그먼트·칩 = 불투명 `surfaceSecondary`" 행(비선택 무채움 + 폴백으로),
    "일지 작성 버튼 = 44pt 원형" 행(라벨 캡슐로)
  - §3.1 — 내부 컨트롤 규정(고채도 채움 최소화·주 액션 trailing·접근성 폴백), 탭별 내용 표
    (순자산 아이콘 삭제·매매일지 라벨 캡슐), overflow 진입점 바닥 규칙 주석
  - §4.3 — 벤치마크 선택 칩 "카테고리색 채움 + 흰 라벨" 조항(wash + dot 로 교체),
    "최대 4개" 조항(개수+폭 병기)
  - §4.4 — 일지 44pt 원형 → 라벨 캡슐
  - §6.3 — 액세서리 내부 컨트롤의 Reduce Transparency 분기 명문화
- `docs/design/2026-07-31-pencil-design-reference.md` — §6.1~6.4 액세서리 서술과 §7 inline 표
- `hannun.pen` — 4탭 액세서리 프레임(`bjQi7`/`kyiZ5`/`EikF0`/`cfHUb`) + inline 스터디(`gMyiS`)
  갱신(Pencil MCP 로만), 이후 `docs/design/assets/pencil/01~04·09` PNG 재출력
- `docs/claude/design-system.md` — Glass variant 표의 액세서리 관련 행

## 8. 선택 사항 / 반려한 대안

**선택 사항** (없어도 목표 달성):
- 통화 토글 슬라이딩 썸(matched-geometry): 마감 향상용. 대가는 모션 복잡도 + Reduce Motion 분기.
- 로딩 캡션 shimmer: 상시 떠 있는 면의 애니메이션은 시선 강탈 위험 — 기본은 정적.

**반려한 대안**:
- **고정 시각 높이 토큰(32/28pt)**: Dynamic Type 클리핑. 콘텐츠+패딩/히트 프레임 분리로 대체.
- **AX 사이즈 `.inline` 강제 + 캡션 숨김**: stale 경고·빈 상태 CTA 를 지우는 접근성 회귀.
- **카테고리 원색 가득 채움 + 색별 on-색 토큰**: 토큰 8조합 개별 검증 필요 + 포화 채움 잔존.
- **선택 시에만 dot 표시**: 선택 전환 시 칩 폭 변동 → 재배치 점프.
- **비선택 `surfaceSecondary` 채움 유지**: 세그먼트-바 문제 잔존. 단 접근성 설정에서는
  스트로크 폴백으로 경계 복원 — "항상 무채움"이 아니라 "기본 무채움 + 조건부 경계".
- **칩 가로 패딩 14 → 12**: 공유 상수라 콘텐츠 칩까지 번짐.
- **보조 액션 `brandTint` wash 바닥**: 다크 실측 3.25:1 로 오히려 악화 — 스트로크로 대체.
- **비활성 전용 토큰 신설 / 비활성 칩 숨김**: 전자는 결과 동일 토큰만 증가, 후자는 PM-4
  취지 삭제 + 폭 예산 변동.
- **캡션 탭 = 수동 갱신 승격**: 갱신은 화면 전체의 동작(시스템 refreshable 문법) — 좌측에
  행동이 생겨 원칙 2 와 충돌.
- **StaleBadge 캡슐화**: 형상 채널("각짐 = 정보") 상실 대가가 심미 통일 이득보다 크다.
- **캡슐 재질·높이 커스텀, 오버플로의 툴바 이동**: §3.1 불변 조건 위반.
- **stale 상태에 `warning` 색**: 신선도는 사용자가 고칠 수 없는 주변 정보 — 중립 유지.

## 9. 구현 후 검증 게이트 (게이트 7)

`[게이트 대기]` 표기 항목은 이 게이트를 통과해야 잠금 해제된다. 나머지 항목은 즉시 구현 가능.

- **시점**: 액세서리 구현 이슈 착수 전 별도 스파이크(0.5~1일).
- **수단**: `#if DEBUG` 검증 프리뷰(4탭 액세서리 × 정상/선택/비활성/stale)를 DesignSystem 에
  만들어 DEBUG 빌드를 **실기기**에 설치·촬영. 시뮬레이터는 유리 렌더링이 달라 판정 근거로
  쓰지 않는다.
- **매트릭스(12셀)**: 배경 2종(순자산 밝은 카드 스크롤 / 성과 차트 위) × 스킴 2종(라이트·다크)
  × 접근성 3종(기본 / Reduce Transparency ON / Increase Contrast ON). 각 셀에서
  expanded·inline 함께 촬영.
- **합격 기준(이분법 판정)**:
  - G1. 선택 칩과 비선택 칩이 팔 길이 거리에서 3초 내 구분된다
  - G2. RT ON 에서 컨트롤과 문구가 구분된다 — 실패 폴백: `surfaceSecondary` 복원 분기 또는
    `separator` 스트로크 강화
  - G3. IC ON 에서 원색 스트로크 승격의 충분성 판정
  - G4. 보조 액션이 캡션과 구분된다 (스트로크 캡슐 처방 검증)
  - G5. inline overflow 진입점이 3초 내 발견된다 — 실패 시 `surfaceSecondary` 원 자동 복귀
  - G6. 비활성 칩이 비선택 칩과 구분되며 "꺼짐"으로 읽힌다 — opacity 값(0.4/0.5/0.6) 확정
  - G7. 4칩 + 상시 dot 이 **375pt 기기 · xxxLarge** 에서 잘리지 않는다 — 실패 시 §3.2 완충
    수단 순차 적용
  - G8. `brand` 라벨/스트로크의 실측 대비가 §3.1 표 값과 부합한다
- **판정·기록**: 판정자는 제품 오너 + 디자이너. 셀별 pass/fail 표와 스크린샷을
  `docs/design/` 부록으로 남기고, 실패 셀은 사전 정의된 폴백을 자동 적용한다(재논의 없음).
  부분 실패 시에도 통과 항목은 잠금을 푼다. 관찰 항목: stale 사각 배지가 캡슐 안에서
  결함처럼 읽히는지(§10 결정 3 재검토 트리거).

## 10. 결정 기록 (2026-08-01, 제품 오너 확정)

| # | 사안 | 결정 | 근거 요약 |
|---|---|---|---|
| 1 | 순자산 캡션 탭 동작 | **정적 유지 + 아이콘 삭제**, `NetWorthScreen` `.refreshable` 추가를 선행 조건으로 | 갱신은 화면 전체의 동작. 현재 순자산 탭에 갱신 수단이 없다는 사실이 확인돼 선행 이슈 필수 |
| 2 | 매매일지 주 액션 형태 | **라벨형 brand 캡슐("작성")** | 스펙 §4.4 FAB 폐지 근거가 이미 라벨형을 가리킴. 구현 전인 지금이 개정 최저 비용 |
| 3 | StaleBadge 형상 | **현행 radiusS 유지** | "각짐 = 정보, 캡슐 = 컨트롤" 비색 채널 보존. §9 관찰 항목으로 재검토 여지만 남김 |
| 4 | inline overflow 채움 | **`neutralTint` wash 원** | 유일 진입점 발견성 > 미학. G5 실패 시 `surfaceSecondary` 자동 복귀 |
| 5 | 비활성 상태 표현 | **opacity 채널** (값은 G6 확정) | 전용 토큰은 결과 동일·토큰만 증가. 칩 숨김은 PM-4 취지 삭제 |
| 6 | 캡션 아이콘 정책 | **캡션 무아이콘** — 아이콘 유무가 컨트롤 신호 | 어포던스 거짓말 제거 + 색맹에도 유효한 채널 |
| 7 | wash 가시성 검증 | **조건부 확정 + 착수 전 실기기 스파이크** (§9) | 문서 정지도 전면 재작업 리스크도 피하는 중간 경로 |
| 8 | 보조 액션 어포던스 | **brand 1pt 스트로크 캡슐**(라이트·다크 공통) + 라이트 brand/다크 textPrimary 라벨 | 아이콘 단독(PM안)은 다크에서 현행과 동일해 진단 3 미해결(리뷰 지적). 스트로크는 3:1 통과·IC 폴백과 수단 통일 |
