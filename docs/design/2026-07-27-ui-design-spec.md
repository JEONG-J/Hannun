# Hannun UI 디자인 설계 문서

- 작성일: 2026-07-27
- 상태: 확정 (Pencil 시안 제작 및 SwiftUI 구현의 기준 문서)
- 근거 문서
  - 제품 설계: `docs/design/2026-07-21-personal-asset-management-ios-app-design.md`
    (기능 ID NW-*/PF-*/PM-*/JR-* 는 이 문서 기준)
  - 프로젝트 디자인 시스템: `docs/claude/design-system.md`
  - Liquid Glass API: `docs/claude/ios26-frameworks/SwiftUI-Implementing-Liquid-Glass-Design.md`
  - 디자인 원칙·모션: apple-design 스킬 (WWDC Designing Fluid Interfaces /
    Principles of Great Design 기반)
  - `tabViewBottomAccessory`: Apple SwiftUI 공식 문서 (developer.apple.com/documentation/swiftui).
    **`docs/claude/ios26-frameworks/` 에는 이 API 문서가 없다** — §3.1 의 시그니처·가용 버전은
    공식 문서에서 직접 확인한 내용이며, 구현 전 최신 문서로 재확인할 것
- 시안 및 구현 레퍼런스
  - Pencil 시안 원본: `hannun.pen` (저장소 루트). **암호화 포맷 — `Read`/`Grep` 불가, Pencil MCP 로만 접근**
  - 시안 해설: `docs/design/2026-07-31-pencil-design-reference.md`
    — 노드 ID 지도, 화면별 실측값, **시안대로 구현하면 안 되는 지점**(폰트·Glass·차트), 미설계 항목
  - 이 문서와 `.pen` 의 토큰 값은 완전히 일치한다(검증 완료). 값이 갈리면 **이 문서가 기준**이다
- 변경 이력
  - 2026-07-27 초안 확정
  - 2026-07-27 §3.1 탭바 하단 액세서리 신설 — 포트폴리오 툴바 액션·매매일지 FAB 폐지,
    순자산 통화 토글·성과 벤치마크 칩을 액세서리로 이관

## 1. 디자인 원칙

apple-design 8원칙 중 이 앱에서 판단 기준으로 삼는 핵심 4가지를 앱 맥락으로 구체화한다.

| 원칙 | Hannun 적용 |
|------|------------|
| Purpose | 화면당 답할 질문 1개 — 순자산 "얼마인가" · 포트폴리오 "무엇을 들고 있나" · 성과 "잘하고 있나" · 일지 "왜 샀나". 무관한 요소 금지 |
| Simplicity | 미니멀리즘이 아니라 위계. 행당 주지표는 1~2개로 제한하고 나머지는 상세로 위임. 밀도 문제는 숨기기가 아니라 그룹핑·접기로 해결 |
| Familiarity | 국내 금융 앱 관례 준수 — 상승=빨강/하락=파랑(토스·업비트), 기간 세그먼트(Stocks), 스와이프 편집. 관례를 함부로 깨지 않는다 |
| Craft | 모든 숫자는 tabular figures, 금액은 우측 정렬, 간격은 토큰 값. "대충 맞춘 값"은 없다. 도넛 색과 리스트 dot 색은 1:1 일치 |

보조 원칙:

- **Agency**: 파괴적 작업(종목 삭제 PF-4, 일지 삭제 JR-3)만 확인 다이얼로그(AlertPrompt).
  그 외 작업은 확인 없이 즉시 반영 — 확인 남발은 습관적 통과를 만든다.
- **Feedback**: 시세 갱신 실패는 빈 화면이 아니라 "마지막 캐시값 + 갱신 실패 배지"로 degrade
  (제품 설계 §8). 상태(loading)·완료·경고·에러 4종 피드백을 화면마다 정의한다(§4).

### Liquid Glass 적용/금지 규칙

Glass는 "콘텐츠 위에 떠 있는 기능 레이어"에만 쓴다. 콘텐츠 자체를 glass로 만들지 않는다.

| 영역 | 규칙 |
|------|------|
| 탭바·내비게이션 바 | 시스템 기본 glass 그대로 사용 (커스텀 배경 금지) |
| 탭바 하단 액세서리 | 캡슐 **컨테이너에만** glass. 내부 컨트롤은 불투명 (§3.1) |
| 컨트롤 레이어 | 필터 칩, 세그먼트, sheet 하단 버튼에 glass 적용 |
| 칩 그룹 | `GlassEffectContainer` + `glassEffectUnion` 필수 (오프스크린 렌더링 절감) |
| 차트 영역 | **glass 금지** — 도넛/라인 차트 배경은 불투명 서피스. 가독성·성능 모두 이유 |
| 고밀도 숫자 영역 | **glass 금지** — 종목 리스트, 금액 표, 총자산 숫자 뒤에 glass를 깔지 않는다 |
| List/Table | glass 적용 불가 (design-system.md 성능 규칙) |

## 2. 디자인 토큰

### 2.1 컬러

다크 모드는 순수 검정 대신 다크 네이비/차콜 베이스를 쓴다(금융 앱 시각 언어 관례).
브랜드 색은 손익 색(빨강/파랑)과 겹치지 않는 인디고 계열 제3의 색으로 분리한다.

#### 기본 팔레트

| 토큰 | 라이트 | 다크 | 용도 |
|------|--------|------|------|
| `backgroundPrimary` | `#F2F3F7` | `#14161F` | 화면 배경 (grouped) |
| `surfacePrimary` | `#FFFFFF` | `#1D2029` | 카드·리스트 셀·sheet 서피스 |
| `surfaceSecondary` | `#E9EBF1` | `#272B36` | 비선택 칩·인풋 필드 배경 |
| `textPrimary` | `#14181F` | `#F2F4F8` | 주 텍스트·금액 |
| `textSecondary` | `#6B7280` | `#9AA1AE` | 보조 텍스트·서브라인·통화기호 |
| `brand` | `#5856D6` | `#6E6CFF` | 브랜드 강조 (인디고 — 손익 색과 분리) |
| `onBrand` | `#FFFFFF` | `#0A0C12` | **`brand` 채움 위 라벨** — 선택된 필터 칩, 액세서리 주요 액션 |
| `separator` | `#E2E4EA` | `#2E3340` | 구분선 (최소 사용, scroll edge effect 우선) |

> **`onBrand` 가 다크에서 흰색이 아닌 이유.** 다크 `brand`(`#6E6CFF`)는 라이트보다 밝아서 흰 라벨의
> 대비가 약 4.0:1 로 떨어진다 — 13pt Semibold 칩 라벨은 WCAG 대형 텍스트가 아니므로 AA(4.5:1) 미달이다.
> 잉크로 뒤집으면 약 4.9:1 이 된다. 다크에서 주 색이 밝아지고 그 위 라벨이 어두워지는 건 표준적인
> on-color 패턴이다. 시안대로 양쪽 다 흰 라벨로 가려면 colorset 다크 값 하나만 바꾸면 된다.
>
> **`brand` 를 라벨 색으로 쓰는 건 옅은 tint 배경 위에서만이다** (`HannunTint`, 알파 12/18% — §2.2).
> 채움(`Glass.tint(brand)` · solid `brand`) 위에 `brand` 라벨을 얹으면 같은 색이라 글자가 사라진다.

#### 손익 색 (확정)

**상승=빨강 / 하락=파랑** — 국내 관례(토스·업비트)를 따른다(Familiarity 원칙).
색상 방향 설정 옵션(해외식 초록/빨강 반전)은 post-MVP 백로그로 미룬다.

| 토큰 | 라이트 | 다크 | 용도 |
|------|--------|------|------|
| `gain` | `#F04452` | `#FF6E6E` | 상승 수익률·수익금 |
| `loss` | `#3182F6` | `#64A8FF` | 하락 수익률·손실금 |
| `neutral` | `#6B7280` | `#9AA1AE` | 변동 0·데이터 없음 |

pill 배경 tint는 위 색의 12% 불투명도(라이트) / 18%(다크)를 쓴다.

#### 카테고리 5색 (도넛·dot·소계 리스트 공용)

무지개 팔레트를 피하고, 채도를 맞춘 5색을 카테고리에 고정 매핑한다.
도넛 섹터 색과 리스트 dot 색은 반드시 1:1 동일 토큰을 쓴다 — 리스트가 곧 범례다.

| 카테고리 | 토큰 | 라이트 | 다크 |
|----------|------|--------|------|
| 현금 | `categoryCash` | `#8A93A6` | `#98A2B8` |
| 국내주식 | `categoryDomestic` | `#5856D6` | `#7C7AFF` |
| 해외주식 | `categoryForeign` | `#06AED4` | `#22C6E6` |
| ETF | `categoryEtf` | `#A855F7` | `#C084FC` |
| 코인 | `categoryCrypto` | `#F59E0B` | `#FBBF24` |

> 현금은 저채도 중립(변동 없는 자산), 코인은 앰버(비트코인 연상), 국내주식은 브랜드 계열.
> `loss` 파랑(`#3182F6`)과 `categoryForeign` 시안은 색상·용처가 달라 혼동 없음을 확인함.

### 2.2 타이포그래피 (SF Pro)

시스템 폰트(SF Pro)만 사용, Dynamic Type 대응 필수. **숫자는 전부 tabular figures**
(`monospacedDigit`) — 스크럽·토글로 숫자가 실시간 치환될 때 폭이 흔들리면 안 된다.

| 토큰 | 크기/웨이트 | tabular | 용도 |
|------|------------|---------|------|
| `displayAmount` | 34pt Bold | 필수 | 총자산·YTD 큰 숫자 (tracking 소폭 타이트) |
| `screenTitle` | 28pt Bold | — | 내비게이션 Large Title |
| `sectionHeading` | 20pt Semibold | — | 섹션 헤더 |
| `rowTitle` | 17pt Semibold | — | 종목명·일지 제목 |
| `rowAmount` | 17pt Semibold | 필수 | 행 우측 평가금액 |
| `body` | 17pt Regular | — | 본문·폼 인풋 |
| `subtext` | 15pt Regular | 숫자 시 | 보조 정보·소계 |
| `caption` | 13pt Regular | 숫자 시 | 서브라인(수량·평단가)·날짜·배지 |
| `pillLabel` | 13pt Semibold | 필수 | 수익률 pill·변동 pill |

금액 표기 위계: 숫자 본체 > 통화기호·소수점. 통화기호(₩/$)와 소수부는
`textSecondary` 색 또는 한 단계 작은 크기로 낮춘다. 금액은 항상 우측 정렬.

### 2.3 스페이싱·코너 반경

| 스케일 | 값(pt) | 용도 |
|--------|--------|------|
| `spacingXS` | 4 | dot–텍스트 간격, pill 내부 상하 |
| `spacingS` | 8 | 행 내부 요소 간격, 칩 간격 |
| `spacingM` | 12 | 카드 내부 패딩(컴팩트), 셀 상하 |
| `spacingL` | 16 | 화면 좌우 마진, 카드 내부 패딩(기본) |
| `spacingXL` | 24 | 섹션 간 간격 |
| `spacingXXL` | 32 | 큰 숫자 블록 상하 여백 |

| 반경 토큰 | 값(pt) | 용도 |
|-----------|--------|------|
| `radiusS` | 8 | 작은 배지·인풋 필드 |
| `radiusM` | 16 | 카드·차트 컨테이너·리스트 그룹 |
| `radiusL` | 24 | sheet 상단 |
| capsule | — | 칩·pill·토글·세그먼트 |

컨테이너 클리핑은 design-system.md의 `ConcentricRectangle` 패턴을 따른다
(`corners: .concentric(minimum: 반경토큰)`, `isUniform: true`).

### 2.4 Glass variant 매핑

design-system.md의 variant 표를 화면 요소에 대응시킨다. 구현 시 이 이름을 그대로 전달한다.

| 화면 요소 | Variant | 비고 |
|-----------|---------|------|
| 필터 칩(벤치마크·종목·카테고리) | `.regular.interactive()` | ChipGroup은 Container+Union 필수 |
| 선택된 칩 | `.regular.tint(brand).interactive()` | 선택 상태를 tint로 구분. **라벨은 `onBrand`** — `tint` 는 알파 wash 가 아니라 채도 그대로의 채움이다 |
| 탭바 하단 액세서리 캡슐 | `.regular` | 컨테이너 자체에만 적용 (§3.1) |
| 액세서리 **내부** 세그먼트·칩 | **glass 금지** | 불투명 `surfaceSecondary` + 선택 시 brand tint |
| 액세서리 **내부** 주요 액션 버튼 | **glass 금지** | `brand` 채움(solid) + `onBrand` 라벨 |
| KRW/USD 통화 토글 | `.regular.interactive()` | capsule. 순자산 탭에서는 액세서리 내부로 이동(§4.1) → glass 금지 규칙 적용 |
| 기간 세그먼트(성과 탭) | `.regular.interactive()` | 차트 아래 인라인 배치 (액세서리 아님 — §4.3) |
| 일지 작성 버튼 | `brand` 채움 | 액세서리 우측 44pt 원형 (FAB 대체 — §4.4) |
| sheet 저장(Primary) 버튼 | `.glassProminent` (ButtonStyle) | |
| sheet 취소(Secondary) 버튼 | `.glass` (ButtonStyle) | |
| 카드·차트·리스트·숫자 영역 | 적용 금지 | §1 규칙 — 불투명 `surfacePrimary` 사용 |

> **glass-on-glass 금지**: 액세서리 캡슐이 이미 반투명 Liquid Glass 면이다. 그 위에
> `.pickerStyle(.segmented)`나 `.glass` 버튼을 얹으면 반투명이 2겹으로 쌓여 가독성이 무너진다
> (apple-design: "Never stack a light translucent surface on another"). 액세서리 내부 컨트롤은
> 반드시 불투명 fill을 쓴다.

## 3. 내비게이션 구조

탭 4개, 탭별 독립 `NavigationStack`(프로젝트 아키텍처 규약). 탭 간 이동(NW-4)은
AppRouter 경유. 편집·작성 플로우는 sheet, 목록형 서브 화면은 push.

```
TabView (+ tabViewBottomAccessory — §3.1)
├── ① 순자산 (NavigationStack)
│     └── (서브 화면 없음 — 카테고리 행 탭 → 포트폴리오 탭 전환 + 필터 적용) [NW-4]
├── ② 포트폴리오 (NavigationStack)
│     ├── 종목 추가 sheet (단계식)                        [PF-2]  진입: 액세서리 "종목 추가"
│     ├── 종목 수정 sheet                                 [PF-3]  진입: 행 스와이프/행 탭
│     └── 입출금 기록 push                                [PF-5/6] 진입: 액세서리 "입출금 기록"
│           └── 입출금 추가·수정 sheet
├── ③ 성과 (NavigationStack — 서브 화면 없음)             [PM-1~4]
└── ④ 매매일지 (NavigationStack)
      ├── 일지 상세 push (수정·삭제 포함)                  [JR-3]  진입: 셀 탭
      └── 일지 작성 fullScreenCover                       [JR-2]  진입: 액세서리 작성 버튼
```

탭 라벨은 구체적으로: "순자산·포트폴리오·성과·일지" (모호한 "홈" 금지 — 직접적 라벨 원칙).
SF Symbols 후보: `chart.pie.fill` / `list.bullet.rectangle` / `chart.line.uptrend.xyaxis` /
`book.closed.fill`.

### 3.1 탭바 하단 액세서리 (tabViewBottomAccessory)

iOS 26 `TabView`는 탭바 바로 위에 떠 있는 Liquid Glass 액세서리를 붙일 수 있다.
**본 앱은 탭별 주요 액션·컨텍스트 컨트롤을 모두 이 자리로 통일한다** — 엄지 도달권
(thumb zone) 안이고, 스크롤과 무관하게 항상 접근 가능하며, 콘텐츠 영역을 침범하지 않는다.
이 결정으로 **포트폴리오 툴바 아이콘 2개와 매매일지 FAB는 제거**된다.

#### 배치 원칙

- 액세서리는 **`TabView`에 하나만** 붙는다 (탭별 modifier가 아님). 탭별 내용은
  `selection` 값으로 분기한다.
- 캡슐 사양: 높이 56pt, `cornerRadius` 28(capsule), 좌우 마진 16pt, 탭바와 간격 8pt,
  `padding` 6pt, `.regular` glass + 배경 블러 + 외부 그림자(0/8/24, 10% black).
- 내부 컨트롤 터치 타깃 **최소 44pt**. 캡슐 안쪽 가용 폭은 iPhone 기준 약 358pt이므로
  **1~2개의 액션 또는 최대 4개의 짧은 칩**까지가 한계다.
- 내부 컨트롤에 glass 재적용 금지 (§2.4 경고). 세그먼트는 `.pickerStyle(.segmented)`
  대신 불투명 커스텀 세그먼트로 만든다.
- 액세서리는 **보조 컨트롤 전용**이다. 파괴적 동작(삭제·초기화)이나 되돌리기 어려운
  동작은 넣지 않는다.

#### 탭별 내용

| 탭 | 좌측 | 우측 | 역할 |
|----|------|------|------|
| ① 순자산 | `arrow.trianglehead.2.clockwise` + "오후 12:04 시세 기준" | KRW / USD 세그먼트 | 시세 신선도 + 통화 전환 [NW-2] |
| ② 포트폴리오 | **종목 추가** (brand 채움, `plus`) | 입출금 기록 (투명, `arrow.left.arrow.right`) | 생성 액션 2개 [PF-2, PF-5/6] |
| ③ 성과 | 벤치마크 칩 4개 — 코스피 / S&P500 / 나스닥 / BTC | — | 비교 대상 전환 [PM-4] |
| ④ 매매일지 | `sparkles` + "오늘의 매매를 기록해보세요" | 작성 버튼 44pt 원형 (brand, `pencil.line`) | 작성 유도 + 진입 [JR-2] |

- 순자산: 통화 토글이 액세서리로 이동하므로 **큰 숫자 옆의 CurrencyToggle은 제거**한다(§4.1).
- 성과: 선택된 칩만 카테고리 색 tint(예: S&P500 → `categoryForeign`), 나머지는
  `surfaceSecondary`. 콘텐츠 영역의 벤치마크 칩 그룹은 제거하고 그만큼 차트를 키운다(§4.3).
- 매매일지: 좌측 힌트 문구는 장식이 아니라 **empty 상태의 CTA 역할**을 겸한다.

#### `.expanded` / `.inline` 대응

`tabBarMinimizeBehavior(.onScrollDown)`로 탭바가 최소화되면 액세서리가 축소 배치로
전환된다. `@Environment(\.tabViewBottomAccessoryPlacement)` 값(`.expanded` / `.inline`)을
읽어 아래처럼 축약한다. **축약해도 주 액션은 절대 사라지지 않는다.**

| 탭 | `.expanded` | `.inline` (축약) |
|----|-------------|------------------|
| ① 순자산 | 갱신 시각 캡션 + KRW/USD 세그먼트 | "12:04 기준" + KRW/USD 세그먼트 |
| ② 포트폴리오 | 종목 추가 + 입출금 기록 | 종목 추가만 전체 폭. 입출금은 툴바 메뉴로 |
| ③ 성과 | 벤치마크 칩 4개 | 현재 벤치마크 1개 + chevron → Menu 전개 |
| ④ 매매일지 | 힌트 문구 + 작성 버튼 | "매매 기록" + 작성 버튼 |

#### API 주의사항

- `tabViewBottomAccessory(content:)` — iOS 26.0+
- `tabViewBottomAccessory(isEnabled:content:)` — **iOS 26.1+**. 배포 타깃이 26.0을
  포함하면 `isEnabled:` 대신 조건 분기로 `EmptyView()`를 반환한다.
- `tabBarMinimizeBehavior(.onScrollDown)`은 **iPhone 전용**. iPad/Mac Catalyst에서는
  탭바가 최소화되지 않으므로 `.inline` 대응은 iPhone 기준으로만 검증한다.
- 액세서리 높이만큼 콘텐츠 하단에 여백이 필요하다 — 리스트 마지막 행이 캡슐에 가리지
  않도록 `safeAreaPadding` 또는 하단 스페이서로 보정한다.

## 4. 화면별 스펙

공통 상태 규칙 (모든 탭 적용):
- **loading**: 첫 로딩만 스켈레톤/redacted. 이후 갱신은 기존 값 유지 + pull-to-refresh
- **갱신 실패**: 마지막 캐시값 유지 + 내비게이션 바 하단에 StaleBadge
  ("갱신 실패 · n분 전 기준") 표시 [NW-1 제약, 제품 설계 §8].
  단 순자산 탭은 하단 액세서리의 갱신 시각 캡션이 이 역할을 대신한다(§4.1)
- **empty**: 각 화면 정의 참조. 빈 화면 방치 금지, 반드시 CTA 포함

### 4.1 순자산 탭 [NW-1 ~ NW-4]

벤치마크: Copilot Money(큰 순자산 숫자), Kubera(자산군 소계 중심), Delta(총액+도넛+비중 결합).

레이아웃 (위→아래):

| 순서 | 요소 | 스펙 |
|------|------|------|
| 1 | 총자산 큰 숫자 | `displayAmount` 단독. **통화 전환(KRW/USD)은 하단 액세서리로 이동** [NW-1, NW-2] |
| 2 | 전일 대비 변동 pill | ChangePill — 금액+% 병기, gain/loss 색 |
| 3 | 도넛 차트 | 카테고리 5색, 중앙 홀에 총액(기본)/선택 카테고리 값 표시 [NW-3] |
| 4 | 카테고리 소계 리스트 | CategoryDot + 이름 + 금액 + 비중%. 탭 → 포트폴리오 필터 이동 [NW-4] |

**확정: 파이 대신 도넛 차트.** 제품 설계 NW-3의 "비중 시각화" 요구를 도넛으로 구체화한다.
근거: ① 중앙 홀에 총액/선택값을 표시해 별도 라벨 없이 정보 밀도 확보 ② 섹터 내부 퍼센트
라벨 불필요 → 소계 리스트가 범례 겸 수치 역할. 차트 옆 별도 범례는 만들지 않는다.

- 도넛 섹터 탭: 해당 섹터 강조 + 중앙 홀 값이 카테고리명/금액으로 전환. 재탭 시 총액 복귀
- 회피: 무지개 색, 파이 내부 % 라벨, 차트 배경 glass
- 하단 액세서리(§3.1): 시세 갱신 시각 캡션 + KRW/USD 세그먼트. 갱신 실패 시 캡션을
  "갱신 실패 · n분 전 기준"으로 바꿔 StaleBadge 역할을 겸한다 — 별도 배지를 띄우지 않는다
- empty (보유 0건): 도넛 자리에 EmptyStateView — "첫 자산을 추가해 보세요" + 종목 추가 CTA

### 4.2 포트폴리오 탭 [PF-1 ~ PF-6]

벤치마크: Delta(종목 행 2단 구조), Yahoo Finance(우측 값 영역 탭 지표 순환).

레이아웃 (위→아래):

| 순서 | 요소 | 스펙 |
|------|------|------|
| 1 | 요약 바 | 총 평가금액 + 총 손익(금액·%) 컴팩트 표시, `rowAmount`/`pillLabel` |
| 2 | 카테고리 필터 ChipGroup | 가로 스크롤. "전체" + 카테고리 5종. NW-4 진입 시 해당 칩 선택 상태로 |
| 3 | 카테고리 섹션 헤더 | CategorySectionHeader — 접기/펼치기 chevron + 카테고리 소계 |
| 4 | 종목 행 (반복) | HoldingRow 2단 구조 (아래) [PF-1] |

HoldingRow 2단 구조:

| 영역 | 내용 |
|------|------|
| 좌상 | 종목명(`rowTitle`) + 티커(`caption`, textSecondary) |
| 좌하 | 서브라인: 수량 · 평단가 (`caption`, tabular) |
| 우상 | 평가금액 (`rowAmount`, tabular, 우측 정렬) |
| 우하 | 수익률 ChangePill (배경 tint) — 탭 시 수익금↔수익률 순환 표시 |

- 행당 주지표는 평가금액+수익률 2개. 현재가·수익금은 우측 pill 탭 순환으로 위임
  (PF-1의 6개 지표를 다중 컬럼 테이블 없이 수용). 다중 컬럼 헤더는 만들지 않는다
- 현금 행: 평단가·수익률 숨김 — 서브라인과 pill 자리를 비운다 [PF-1 제약]
- 스와이프: leading 수정 [PF-3] / trailing 삭제 [PF-4]. 삭제는 AlertPrompt 확인 후 실행
- 하단 액세서리(§3.1): **종목 추가**(brand 채움) → 단계식 sheet [PF-2] /
  **입출금 기록**(투명) → push [PF-5/6]. 툴바에는 두 액션을 중복 배치하지 않는다
- **카테고리 필터는 액세서리에 넣지 않는다.** 캡슐 가용 폭 358pt를 5분할하면 약 71pt로
  한글 라벨(국내주식·해외주식)과 44pt 터치 타깃을 동시에 만족할 수 없고, 생성 액션 자리를
  뺏는다. 필터는 요약 바 아래 가로 스크롤 ChipGroup으로 둔다
- empty: EmptyStateView + "종목 추가" CTA (`.glassProminent`)

#### 서브: 종목 추가 sheet [PF-2]

단계식 진행 — 한 화면에 폼 전체를 펼치지 않는다(Simplicity).

| 단계 | 내용 |
|------|------|
| 1 | 자산유형 선택 (현금/국내주식/해외주식/ETF/코인 — 카테고리 색 dot 병기) |
| 2 | 종목명/티커 입력·검색 (현금이면 통화 선택으로 대체) |
| 3 | 수량 + 평단가 입력 (현금은 금액만). 숫자 키패드, tabular 미리보기 |

- 시세 미지원 종목: 3단계에서 "현재가 수동 입력" 필드 노출 (폴백) [PF-2 제약]
- 하단: 저장 `.glassProminent` / 취소 `.glass`. 제목 등 필수값 미입력 시 저장 비활성

#### 서브: 종목 수정 sheet [PF-3]

수량·평단가 2필드만 편집. 저장 시 화면 값 즉시 재계산. 단일 화면 sheet(medium detent).

#### 서브: 입출금 기록 [PF-5, PF-6]

- 목록(push): 월별 섹션 그룹핑, 행 = 날짜·유형(입금/출금)·금액·메모.
  입금 금액은 `textPrimary`, 출금은 부호(−)로 구분 — 손익 색은 여기 쓰지 않는다
  (입출금은 손익이 아님)
- 추가/수정 sheet: 날짜·금액·통화·유형(세그먼트)·메모 폼. 저장 시 성과 지표 자동 재계산
  안내 불필요(백그라운드 처리) [PF-6]
- 삭제: 스와이프 + AlertPrompt
- empty: "입출금 기록이 없습니다" + 추가 CTA

### 4.3 성과 탭 [PM-1 ~ PM-4]

벤치마크: Apple Stocks(기간 세그먼트), Portfolio Performance(정규화 벤치마크 오버레이),
Robinhood(스크럽 시 상단 숫자 실시간 치환 + 햅틱).

레이아웃 (위→아래):

| 순서 | 요소 | 스펙 |
|------|------|------|
| 1 | YTD 수익률 큰 숫자 | `displayAmount`, gain/loss 색. 입출금 제외 순수 성과 [PM-3] |
| 2 | 자산 추이 라인 차트 | TrendLineChart — area gradient(brand 계열), 스크럽 지원 [PM-2]. 플롯 높이 320pt |
| 3 | 단위·기간 컨트롤 | 일별/월별 토글 + 기간 세그먼트(1M/3M/6M/YTD/1Y/ALL) [PM-2] |

벤치마크 칩 그룹(코스피/S&P500/나스닥/BTC)은 **콘텐츠 영역이 아니라 하단 액세서리**에
둔다(§3.1). 그만큼 확보한 세로 공간은 차트 플롯에 되돌려준다(200 → 320pt).

벤치마크 오버레이 규칙 [PM-4]:
- **반드시 % 정규화** — 선택 기간 시작점=0%로 내 수익률과 벤치마크를 같은 축에 오버레이.
  금액 축과 지수 값을 같은 축에 겹치는 것 금지
- 내 라인 굵게(brand, 2pt) / 벤치마크는 얇은 중립색 1pt 60% 불투명도
- 기본 표시 벤치마크 0~1개. 칩 선택 색 = 라인 색 (칩이 범례 — 별도 범례 없음)
- 액세서리 폭 제약상 칩은 **최대 4개까지만** 노출한다. 그 이상은 `.inline` 규칙과 동일하게
  Menu로 전개한다
- 벤치마크 조회 실패 시 해당 라인만 생략, 칩에 비활성 표시 [PM-4 제약]

스크럽: 드래그 시 상단 YTD 숫자가 해당 시점 값으로 실시간 치환 + 세로 인디케이터.
데이터 포인트 스냅 시 selection 햅틱. 손을 떼면 현재 값으로 복귀 (§6 참조).

- **기간 세그먼트는 차트 바로 아래 인라인 유지.** 액세서리 자리는 벤치마크 칩이 차지한다 —
  기간과 벤치마크를 한 캡슐에 함께 넣으면 358pt 안에서 둘 다 44pt 터치 타깃을 못 지킨다.
  기간은 차트 축과 직결된 컨트롤이라 차트에 붙어 있는 편이 인지적으로도 맞다
- 차트 배경 glass 금지 — `surfacePrimary` 카드(`radiusM`) 위에 그린다
- 데이터 1건 이하: 차트 대신 안내 문구 "데이터가 쌓이면 추이가 표시됩니다" [PM-2 제약]

### 4.4 매매일지 탭 [JR-1 ~ JR-4]

벤치마크: TradesViz(노트+종목 태그), Bear(태그 필터 칩·셀 구조), Apple Journal(날짜 표시).

레이아웃 (위→아래):

| 순서 | 요소 | 스펙 |
|------|------|------|
| 1 | 검색 바 | 시스템 searchable — 제목·본문 검색 |
| 2 | 종목 필터 칩 | 가로 스크롤 ChipGroup — 연결 종목별 필터, 단일 선택 [JR-4] |
| 3 | 일지 리스트 | JournalCell 최신순 [JR-1] |

**FAB 폐지 → 하단 액세서리 작성 바**(§3.1). 우하단 떠 있는 원형 버튼 대신 액세서리
캡슐 안에 `sparkles` + "오늘의 매매를 기록해보세요" 힌트와 44pt brand 원형 작성 버튼을
둔다. 근거: ① FAB는 마지막 셀을 가리는데 액세서리는 레이아웃에 자리를 잡는다
② 힌트 문구가 작성 동기를 만들어 빈 아이콘 버튼보다 CTA로 강하다 ③ 4개 탭이 동일한
액션 위치를 갖게 되어 예측 가능성이 올라간다.

JournalCell: 날짜(`caption`, textSecondary, 보조) + 제목(`rowTitle`, 주) +
본문 미리보기 1줄(`subtext`) + 연결 종목 TagPill(중립 tint, 최대 3개 + "+n").

- 셀 탭 → 일지 상세 push (본문 전체 + 수정/삭제 툴바, 삭제는 AlertPrompt) [JR-3]
- empty: EmptyStateView — "첫 매매일지를 남겨보세요" + 작성 CTA [JR-1 제약].
  액세서리 힌트 문구가 이미 CTA 역할을 하므로 EmptyStateView의 버튼은 생략 가능
- 회피: 폴더 계층, 리치 텍스트 툴바 — 자유 서술 텍스트만

#### 서브: 일지 작성 fullScreenCover [JR-2]

| 순서 | 요소 | 스펙 |
|------|------|------|
| 1 | 제목 필드 | `rowTitle` 크기 placeholder. **필수값 — 비면 저장 비활성** |
| 2 | 본문 에디터 | 자유 서술, `body`. 서식 도구 없음 |
| 3 | 종목 태그 선택 | 보유 종목 칩 다중 선택(0개 이상, 선택 사항) — ChipGroup |

날짜는 작성 시각 자동 기록(입력 UI 없음). 하단 저장 `.glassProminent` / 닫기 `.glass`.
작성 중 닫기 시도 시 내용이 있으면 AlertPrompt("작성 중인 내용을 버릴까요?").

## 5. 공통 컴포넌트 인벤토리

| 컴포넌트 | 용도 | 변형 |
|----------|------|------|
| AmountText | 금액 표시 — tabular, 통화기호·소수부 위계 낮춤, 우측 정렬 | display(34) / row(17) / sub(13) |
| ChangePill | 수익률·변동 표시, 배경 tint capsule | gain / loss / neutral · 금액+% / %만 |
| CategoryDot | 카테고리 색 원형 표식 (8pt) | 카테고리 5색 |
| DonutChart | 자산군 비중 — 중앙 홀 값 표시, 섹터 선택 | 기본 / 섹터 선택 상태 |
| TrendLineChart | 자산 추이·벤치마크 오버레이, area gradient, 스크럽 | 단독 / 벤치마크 오버레이 |
| FilterChip · ChipGroup | 필터·다중 선택 — glass union 그룹 | 선택 / 비선택 / 비활성 · 콘텐츠용(glass) / 액세서리용(불투명) |
| CurrencyToggle | KRW/USD 전환 세그먼트 — 순자산 액세서리 내부 | KRW 선택 / USD 선택 |
| PeriodSegment | 기간 선택 1M~ALL 세그먼트 | 인라인 전용(성과 탭 차트 하단) |
| BottomAccessory | 탭바 하단 glass 캡슐 컨테이너 — 56pt, capsule, blur+shadow | 탭 4종 콘텐츠 × `.expanded` / `.inline` |
| AccessoryActionButton | 액세서리 내부 액션 버튼 (불투명) | primary(brand 채움) / secondary(투명) / 아이콘 44pt 원형 |
| HoldingRow | 종목 행 2단 구조 | 기본 / 현금(평단가·pill 숨김) |
| CategorySectionHeader | 카테고리 그룹 헤더 — 접기/펼치기 + 소계 | 펼침 / 접힘 |
| JournalCell | 일지 리스트 셀 — 날짜·제목·미리보기·태그 | 태그 있음 / 없음 |
| TagPill | 종목 태그 표식 — 중립 tint capsule | 셀 내 표시용 / 선택형(작성 화면) |
| StaleBadge | "갱신 실패 · n분 전 기준" 경고 배지 | — |
| EmptyStateView | 빈 상태 — 아이콘 + 문구 + CTA 버튼 | 탭별 문구·CTA 차등 |
| SummaryBar | 포트폴리오 상단 총액+손익 컴팩트 바 | — |

## 6. 모션/인터랙션 가이드

apple-design 스킬(Designing Fluid Interfaces) 기준. SwiftUI에 전달할 파라미터를 명시한다.

### 6.1 스프링 기본값

| 용도 | damping | response | 적용 대상 |
|------|---------|----------|-----------|
| 기본 UI 전환 | 1.0 | 0.35 | 접기/펼치기, 칩 선택, 값 전환, 필터 적용 |
| 모멘텀 인터랙션 | 0.8 | 0.3 | sheet 드래그 해제, 스와이프 액션, 플릭 |
| sheet 등장 | 1.0 | 0.4 | 시스템 present (bounce 없음 — 제스처 없이 등장하므로) |

원칙: 기본은 critically damped(1.0). **bounce(0.8)는 사용자 제스처가 모멘텀을 실었을 때만**
— 그냥 나타나는 메뉴에 overshoot를 주지 않는다.

### 6.2 인터랙션별 스펙

| 인터랙션 | 스펙 |
|----------|------|
| 통화 토글 (NW-2) | 터치다운 즉시 반영. 숫자는 `.numericText()` 전환 + 스프링 1.0/0.3. 레이아웃 점프 방지 = tabular 전제 |
| 차트 스크럽 (PM) | 드래그 1:1 트래킹, 상단 숫자 실시간 치환. 포인트 스냅 시 selection 햅틱. 릴리스 시 스프링 1.0/0.35로 현재값 복귀 |
| 도넛 섹터 선택 (NW-3) | 섹터 확대(스케일 1.04) + 중앙 홀 값 crossfade, 스프링 1.0/0.35 |
| 섹션 접기/펼치기 (PF) | 스프링 1.0/0.35. 접히는 행은 페이드+높이 축소 동시 |
| 스와이프 액션 (PF/JR) | 시스템 스와이프 사용 — 자체 구현 금지 |
| sheet 드래그 해제 | 릴리스 velocity를 스프링 초기 속도로 핸드오프, 0.8/0.3. 위치가 아닌 **velocity 부호**로 복귀/해제 판정 |
| 칩 선택 | glass union 내 tint 전환, 스프링 1.0/0.3. 터치다운 즉시 하이라이트 |
| 액세서리 작성 버튼 → 작성 화면 (JR-2) | 액세서리 버튼에서 화면이 자라나는 앵커 전환(glassEffectID 모핑 후보 — 성능 확인 후 적용). 등장·해제 경로 대칭 |
| 액세서리 `.expanded` ↔ `.inline` | 시스템 전환에 맡기고 내부 콘텐츠만 crossfade + 스프링 1.0/0.3. 스크롤 중 발생하므로 bounce 금지 |
| 탭 전환 시 액세서리 내용 교체 | 캡슐 형태는 유지한 채 내부만 crossfade(0.2s). 캡슐 자체를 사라졌다 나타나게 하지 않는다 |
| 갱신(pull-to-refresh) | 시스템 refreshable. 완료 시 숫자 변화만 `.numericText()` 전환, 성공 햅틱 없음(과잉 피드백 방지) |

### 6.3 인터럽션·접근성 원칙

- **전환 중 입력 잠금 금지.** 모든 애니메이션은 현재 표시값(presentation value)에서 새 목표로
  재시작 — 값 점프 없이 방향 전환 가능해야 한다
- 햅틱은 의미 있는 순간만: 스크럽 스냅, 파괴적 작업 확인, 저장 완료. 시각 피드백과 같은
  프레임에 발화
- Reduce Motion: 슬라이드·스프링을 짧은 크로스페이드로 대체, overshoot 전면 제거.
  Reduce Transparency: glass 서피스를 불투명 `surfaceSecondary`로 대체
- 숫자 큰 폭 변경(통화 토글) 시 밝기 급변 없음 — 색 유지, 값만 전환

## 7. Pencil 제작 가이드

### 7.1 제작 목록·우선순위

| 우선순위 | 화면 | 비고 |
|----------|------|------|
| P1-1 | 순자산 탭 | 앱의 얼굴 — 토큰·도넛·리스트 패턴의 기준 화면 |
| P1-2 | 포트폴리오 탭 | HoldingRow·섹션 헤더 패턴 확정 |
| P1-3 | 성과 탭 | 차트·칩·세그먼트 패턴 확정 |
| P1-4 | 매매일지 탭 | 셀·태그·액세서리 작성 바 패턴 확정 |
| P1-5 | 액세서리 `.inline` 대응 시트 | 4탭 축약형 캡슐 비교 스터디 (§3.1) |
| P2-1 | 종목 추가 sheet | 3단계 중 대표 1프레임(3단계 수량·평단가 입력) |
| P2-2 | 일지 작성 화면 | fullScreenCover |
| P2-3 | 입출금 기록 목록 | push 화면 |
| P2-4 | 종목 수정 sheet | medium detent |

### 7.2 제작 규칙

- **화면당 프레임 1개** — 상태 변형(empty/스크럽 중 등)은 프레임을 늘리지 않고
  주석(annotation)으로 표기
- **라이트 모드 먼저** 제작. 다크는 P1 4탭 확정 후 토큰 표(§2.1)로 일괄 파생
- 프레임 크기: 402×874 (iPhone 16 Pro, pt 기준)
- 색·크기·간격은 반드시 §2 토큰 값 사용 — 임의 값 발견 시 시안 반려
- glass 요소(칩·토글·세그먼트·액세서리 캡슐)는 반투명 흰색 fill(라이트 기준 60%) + 블러로
  근사 표현, 레이어명에 `glass/` 접두어를 붙여 구현 시 variant 매핑(§2.4)이 가능하게 한다
- **하단 액세서리는 재사용 컴포넌트 1개 + 슬롯**으로 만든다 — 캡슐(`glass/AccessoryCapsule`)을
  reusable로 두고 내부 콘텐츠만 탭별로 교체한다. 탭마다 캡슐을 복제하지 않는다
- **액세서리 내부에는 `glass/` 접두어 레이어를 두지 않는다** — 불투명 fill로 그린다
  (glass-on-glass 금지, §2.4)
- 액세서리 배치 좌표: 402pt 프레임 기준 y=742(높이 56), 탭바 상단 y=806 — 간격 8pt
- 탭바·내비게이션 바는 시스템 기본 형태로 그린다 (커스텀 금지)
- 숫자 mock 데이터는 자릿수가 다른 값을 섞어 (예: ₩128,450,000 / $96,412.50) 정렬·tabular
  동작이 검증되게 구성한다

## 부록: post-MVP 백로그 (디자인 관련)

- 손익 색상 방향 설정 옵션 (빨강/파랑 ↔ 초록/빨강 반전) — 설정 화면 신설 시 함께
- 종목 행 우측 지표 순환의 기본값 사용자 지정
- 다크 모드 전용 차트 gradient 미세 조정
