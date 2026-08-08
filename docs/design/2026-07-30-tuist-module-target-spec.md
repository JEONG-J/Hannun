# Hannun Tuist 모듈-타깃 구성 문서

- 작성일: 2026-07-30
- 개정: 2026-07-31 — **네트워킹에서 Moya를 제거하고 `URLSession` + actor 직접 구현으로 전환** (§10.4)
- 개정: 2026-08-01 — **단일 `Project.swift` 에서 다중 프로젝트 워크스페이스로 전환** (§5, §10.6)
- 상태: M0 스캐폴딩 + 네트워크 계층(업비트) 구현 완료
- 선행 문서
  - `docs/design/2026-07-21-personal-asset-management-ios-app-design.md` (기능 명세·데이터 모델·외부 API)
  - `docs/design/2026-07-27-ui-design-spec.md` (디자인 토큰·컴포넌트 인벤토리)
  - `docs/claude/architecture.md` (계층 원칙·DIContainer·에러 처리)

이 문서는 **"무엇을 만드는가"(기능 명세)와 "어떻게 보이는가"(UI 스펙) 사이에 빠져 있던
"어떤 타깃에 담는가"** 를 정의한다. 코드 한 줄 쓰기 전에 확정해야 하는 물리적 경계
(타깃 목록 / 의존성 방향 / 디렉터리 / Tuist manifest)만 다루고, 개별 기능 구현 상세는
다루지 않는다.

## 1. 결정 요약

| 항목 | 결정 | 근거 |
|---|---|---|
| 프로젝트 형태 | **`Workspace.swift` + 모듈당 `Project.swift`** (다중 프로젝트 워크스페이스) | 모듈 경계가 파일 경계와 일치해 매니페스트 diff가 모듈 단위로 떨어지고, `Modules/*`·`Features/*` glob 덕에 새 모듈은 디렉터리만 만들면 등록된다 (§10.6) |
| 모듈 분할 축 | **Feature는 Presentation만 분할, Domain/Data는 공유** | SwiftData 스키마가 단일 ModelContainer로 묶이고, 4개 탭이 같은 엔티티를 교차 참조 (§10.1) |
| 타깃 수 | 앱 1 + 공유 5 + Feature 4 = **10** (+ 테스트 5) | |
| product type | 전부 `.staticFramework` (앱만 `.app`) | dylib 로딩 오버헤드 없음. 리소스는 Tuist 번들 접근자로 해결 (§9.1) |
| 네트워킹 | **`URLSession` + actor 직접 구현** (`Endpoint` 프로토콜 + `NetworkClient` actor) | 호출하는 API가 GET 6~7개 + POST 1개뿐이라 Moya의 실익이 어댑터 비용을 넘지 못했다. 직접 구현이 전 타깃 Swift 6 complete 를 지킨다 (§10.4) |
| 외부 의존성 | **없음** — `Tuist/Package.swift` 자체가 없다 | SwiftData·Swift Charts·`Synchronization` 은 시스템 프레임워크. `tuist install` 단계가 사라진다 (§5.7) |
| 툴체인 | **Tuist 4.202.6** — `mise.toml` 로 프로젝트 고정 (§7.1) | 머신 간 버전 편차 제거. `tuist@latest` 는 canary를 물어오므로 금지 |
| 테스트 프레임워크 | **Swift Testing** (`import Testing`) — XCTest 신규 작성 금지 | toolchain 내장이라 의존성 0. 파라미터화(`@Test(arguments:)`)가 YTD·환산 케이스 표에 그대로 맞음. 단 **기본 병렬 실행**이라 공유 상태 주의 (§6.2) |
| Swift 버전 | Swift 6 language mode + `SWIFT_STRICT_CONCURRENCY=complete` | 로컬 toolchain Swift 6.3.3 확인 |
| 배포 타깃 | **iOS 26.4** | Liquid Glass / `tabViewBottomAccessory` / `ConcentricRectangle` 필수 (§11-①) |

## 2. 타깃 목록

| # | 타깃 | product | 책임 | 의존 |
|---|---|---|---|---|
| 1 | `Hannun` | `.app` | 엔트리포인트, `RootTabView`, `AppRouter` 실체, **DIContainer 등록**, ModelContainer 주입, Info.plist·entitlements | Feature 4종, `HannunData` |
| 2 | `HannunCore` | `.staticFramework` | 공유 커널 — 값 타입(`Money`/`Currency`/`AssetCategory`), `Loadable`, `AppError`, `ErrorHandler`, `AlertPrompt` 모델, `DIContainer`, 라우팅 프로토콜·`AppRoute`, 포매터 | 없음 |
| 3 | `HannunDesignSystem` | `.staticFramework` | 디자인 토큰(§2.1~2.4), Glass 헬퍼, 공통 컴포넌트 18종, `ErrorView`/`EmptyStateView`, `.alertPrompt(item:)` 모디파이어 | `HannunCore` |
| 4 | `HannunDomain` | `.staticFramework` | SwiftData 엔티티 5종, Repository·Service 프로토콜, UseCase 전체 | `HannunCore` |
| 5 | `HannunData` | `.staticFramework` | Repository 구현체, `ModelContainer` 팩토리(CloudKit), **`Endpoint` 선언·`NetworkClient` actor**, DTO, 시세 캐시 | `HannunDomain`, `HannunCore` |
| 6 | `NetWorthFeature` | `.staticFramework` | `NW-1`~`NW-4` View/ViewModel/Components/Router | Domain, DesignSystem, Core |
| 7 | `PortfolioFeature` | `.staticFramework` | `PF-1`~`PF-6` | 동일 |
| 8 | `PerformanceFeature` | `.staticFramework` | `PM-1`~`PM-4` | 동일 |
| 9 | `JournalFeature` | `.staticFramework` | `JR-1`~`JR-4` | 동일 |
| 10 | `HannunTestSupport` | `.staticFramework` | 테스트 타깃 전용 fake·fixture (`MockMarketDataService`, 인메모리 ModelContainer, 샘플 Holding, **`StubURLProtocol`**) | `HannunDomain`, `HannunCore` |

> `HannunTestSupport`는 테스트 타깃만 링크하므로 앱 바이너리에 포함되지 않는다.
> 반면 **프리뷰·개발용 mock 데이터는 각 모듈 내부에 `#if DEBUG` 로 둔다** (CLAUDE.md 절대규칙 3).

### 기능 ID → 타깃 매핑

| 기능 ID | Presentation | UseCase | Repository |
|---|---|---|---|
| `NW-1`~`NW-4` | `NetWorthFeature` | `HannunDomain/UseCases/NetWorth` | `HannunData` (Holding, 환율) |
| `PF-1`~`PF-6` | `PortfolioFeature` | `HannunDomain/UseCases/Portfolio` | `HannunData` (Holding, CashFlowEvent) |
| `PM-1`~`PM-4` | `PerformanceFeature` | `HannunDomain/UseCases/Performance` | `HannunData` (Snapshot, Benchmark) |
| `JR-1`~`JR-4` | `JournalFeature` | `HannunDomain/UseCases/Journal` | `HannunData` (JournalEntry) |

## 3. 의존성 방향

```
L4   Hannun (.app)
       ├─→ NetWorthFeature · PortfolioFeature · PerformanceFeature · JournalFeature
       └─→ HannunData                    ← 구현체를 아는 유일한 타깃 (DI 등록 지점)

L3   *Feature
       ├─→ HannunDomain                  ← UseCase 프로토콜만 사용
       ├─→ HannunDesignSystem
       └─→ HannunCore

L2   HannunData         ─→ HannunDomain, HannunCore
     HannunDomain       ─→ HannunCore
     HannunDesignSystem ─→ HannunCore

L1   HannunCore         ─→ (없음)
```

### 금지 간선

| 금지 | 이유 | 위반 시 증상 |
|---|---|---|
| `*Feature` → `HannunData` | DIP 위반. ViewModel이 구현체를 알게 됨 | 테스트에서 mock 주입 불가, 네트워크 없이 프리뷰 불가 |
| `*Feature` → `*Feature` | 탭 간 결합. `NW-4`의 포트폴리오 탭 이동은 `HannunCore`의 `AppRoute` 경유 | 순환 의존, 빌드 시간 폭증 |
| `HannunDomain` → SwiftUI / DesignSystem | 도메인이 UI 프레임워크에 묶임 | UseCase 단위 테스트가 UI 의존성을 끌고 옴 |
| `HannunDesignSystem` → `HannunDomain` | 디자인 시스템이 엔티티 변경마다 재빌드 | 컴포넌트가 도메인에 종속되어 프리뷰 격리 불가 |
| `HannunCore` → 그 외 전부 | 커널은 잎 노드 | 순환 의존 |
| **`HannunData` 외 어떤 타깃도 → 네트워크 타입** | 전송 계층 교체 가능성을 `MarketDataServiceProtocol` 뒤에 봉인 | `URLResponse`·상태 코드가 ViewModel까지 새어 나가 전송 방식 교체 시 전 계층 수정 |

**네트워크 봉인 규칙 3가지** — 전송 계층 타입은 `HannunData` **내부**에만 존재한다.

1. `Endpoint`·`NetworkClient`·`HTTPMethod`·DTO는 전부 **`internal`** 이다. `HannunData` 에서
   `public` 인 것은 Repository 구현체뿐이다 — 모듈 밖에서는 이름조차 보이지 않는다.
2. `URLError`·HTTP 상태 코드는 `NetworkClient` 밖으로 내보내지 않는다. 경계에서 `HannunCore`의
   `AppError` 로 변환한다. `AppError` 는 Core에 있고 Core는 `URLSession` 을 모르므로,
   **변환 코드는 `HannunData`에 확장으로 둔다** (`AppError+Transport.swift`, §9.5).
3. `MarketDataServiceProtocol`(Domain) 시그니처에는 전송 타입이 등장하지 않는다 — 도메인 값 타입만.

`tuist inspect dependencies --only implicit`(= `make inspect`)로 암묵적 링크를 차단한다(§8).

### DesignSystem이 도메인 타입을 쓰지 않는 방법

`CategoryDot`·`AmountText`는 `AssetCategory`/`Currency`가 필요한데, 이 값 타입들을
`HannunDomain`이 아니라 **`HannunCore`(공유 커널)** 에 두어 해결한다.

```swift
// HannunCore
public enum AssetCategory: String, CaseIterable, Sendable { case cash, domesticStock, overseasStock, etf, crypto }
public enum Currency: String, Sendable { case krw, usd }
public struct Money: Equatable, Sendable { public let amount: Decimal; public let currency: Currency }

// HannunDesignSystem — Core만 알면 충분
public struct CategoryDot: View { public init(_ category: AssetCategory) { ... } }
```

`@Model` 엔티티(`Holding` 등)는 `HannunDomain`에 남는다. DesignSystem은 엔티티를 절대 보지 않는다.

## 4. 디렉터리 레이아웃

**모듈 하나 = 디렉터리 하나 = `Project.swift` 하나.** 워크스페이스는 `Modules/*`·`Features/*`
glob 으로 이들을 빨아들이므로, 새 모듈은 디렉터리를 만들고 `Project.swift` 만 두면 등록된다.

```
Hannun/
├── mise.toml                          # Tuist 버전 고정 (§7.1) — 커밋
├── Tuist.swift                        # 생성 옵션 (구 Tuist/Config.swift)
├── Workspace.swift                    # 프로젝트 glob — 모듈 추가 시에도 고칠 일 없음
├── Project.swift                      # 앱 타깃 하나만
├── Tuist/
│   └── ProjectDescriptionHelpers/     # Package.swift 없음 — 외부 의존성 0 (§5.7)
│       ├── ProjectSettings.swift      # bundleId prefix, destinations, 공통 settings
│       ├── Project+Module.swift       # moduleProject(...) 팩토리
│       └── Project+Feature.swift      # featureProject(...) 팩토리
├── App/
│   ├── Sources/
│   │   ├── HannunApp.swift            # @main, ModelContainer 주입
│   │   ├── RootTabView.swift          # TabView + tabViewBottomAccessory
│   │   ├── Router/AppRouter.swift     # 탭 간 전환·딥링크 조율
│   │   └── DI/DIRegistration.swift    # container.register(...) 전체
│   ├── Resources/{Assets.xcassets, Info.plist}
│   └── Config/
│       ├── Hannun.shared.xcconfig
│       ├── Hannun.debug.xcconfig      # KIS 키 (gitignore)
│       ├── Hannun.release.xcconfig    # KIS 키 (gitignore)
│       └── Hannun.entitlements        # iCloud/CloudKit
├── Modules/
│   ├── Core/{Project.swift,Sources,Tests}
│   ├── DesignSystem/{Project.swift,Sources,Resources}
│   ├── Domain/{Project.swift,Sources,Tests}
│   ├── Data/{Project.swift,Sources,Tests}
│   └── TestSupport/{Project.swift,Sources}
└── Features/
    ├── NetWorth/{Project.swift,Sources}
    ├── Portfolio/{Project.swift,Sources,Tests}
    ├── Performance/{Project.swift,Sources,Tests}
    └── Journal/{Project.swift,Sources}
```

> `Sources/**`·`Tests/**`·`Resources/**` 경로는 이제 **모듈 디렉터리 기준 상대 경로**다.
> 저장소 루트를 기준으로 삼는 건 다른 모듈을 참조할 때뿐 —
> `.project(target: "HannunCore", path: .relativeToRoot("Modules/Core"))`.

### 4.1 `Modules/Domain/Sources`

```
Entities/       Holding · CashFlowEvent · NetWorthSnapshot · BenchmarkSnapshot · JournalEntry
Interfaces/     HoldingRepositoryProtocol · CashFlowRepositoryProtocol
                SnapshotRepositoryProtocol · JournalRepositoryProtocol
                MarketDataServiceProtocol
UseCases/
├── NetWorth/     FetchNetWorthUseCase · FetchCategoryBreakdownUseCase
├── Portfolio/    FetchHoldingsUseCase · SaveHoldingUseCase · DeleteHoldingUseCase
│                 ManageCashFlowUseCase
├── Performance/  RecordSnapshotUseCase · FetchNetWorthTrendUseCase
│                 CalculateYTDReturnUseCase · CompareBenchmarkUseCase
└── Journal/      FetchJournalUseCase · SaveJournalUseCase · FilterJournalByHoldingUseCase
```

UseCase를 Feature가 아니라 Domain에 두는 이유: `FetchHoldingsUseCase`는 `PortfolioFeature`와
`NetWorthFeature`가, 환율 환산은 3개 탭이 공유한다. Feature에 두면 즉시 Feature↔Feature 의존이
생긴다.

### 4.2 `Modules/Data/Sources`

```
Persistence/
├── HannunModelContainer.swift      # CloudKit 설정 포함 팩토리
└── Repositories/                   # Holding/CashFlow/Snapshot/Journal Repository
Network/                            # 전송 계층 — 전부 internal (§3 봉인 규칙 1)
├── HTTPMethod.swift                # get · post 두 케이스
├── Endpoint.swift                  # 요청 선언 프로토콜 + makeRequest() 기본 구현
├── NetworkClient.swift             # actor — URLSession 호출·401 재시도·에러 변환
└── AppError+Transport.swift        # URLError·상태 코드 → AppError (Core 오염 방지, §9.5)
Upbit/
├── UpbitEndpoint.swift             # /v1/ticker (인증 없음)
├── UpbitTickerDTO.swift            # trade_price → Money (Decimal 정밀도 보존)
└── UpbitClient.swift               # struct — 가변 상태 없음
KIS/                                # TODO: 업비트 검증 후 착수 (§11.2)
├── KISEndpoint.swift               # tr_id 헤더를 케이스별로 선언
├── KISTokenStore.swift             # actor — access token → Keychain
├── KISTokenProvider.swift          # actor — RequestAuthorizing 구현·발급 요청 합류
├── KISClient.swift
└── DTO/                            # KISQuoteDTO · KISTokenDTO · KISIndexDTO …
Cache/
└── QuoteCache.swift                # actor — 15분 TTL, 마지막 성공값 보존 (StaleBadge 근거)
Repositories/
└── MarketDataRepository.swift      # MarketDataServiceProtocol 구현 (KIS+업비트 합성)
```

KIS와 업비트를 각각 별도 `Endpoint` 로 둔다. baseURL·인증 방식·헤더 규칙이 완전히 달라
하나의 enum에 합치면 `headers`/`authentication` switch가 두 API의 분기를 섞게 된다.
두 클라이언트를 `MarketDataRepository` 가 합성해 Domain에는 프로토콜 하나로 보인다.

**actor를 쓰는 곳과 쓰지 않는 곳** — 공유 가변 상태가 실제로 있는 타입만 actor다.

| 타입 | 종류 | 이유 |
|---|---|---|
| `NetworkClient` | `actor` | 401 재시도 시퀀스를 직렬화한다. 이후 호출량 제한 게이트도 여기 들어간다 |
| `QuoteCache` | `actor` | TTL 딕셔너리가 가변 상태다. Swift 6 complete 에서 `class` + 가변 딕셔너리는 컴파일되지 않는다 |
| `KISTokenStore`·`KISTokenProvider` | `actor` | 토큰이 가변이고, 동시 발급 요청을 하나로 합류시켜야 한다 |
| `UpbitClient`·`MarketDataRepository` | `struct` | 가변 상태가 없다. actor로 만들면 불필요한 suspension 만 생긴다 |

### 4.3 `Features/{Feature}/Sources`

```
Views/         화면 단위 SwiftUI View
ViewModels/    @Observable ViewModel (Loadable 상태 보유)
Components/    해당 Feature 전용 컴포넌트 (재사용되면 DesignSystem으로 승격)
Router/        Feature 내부 화면 전환
```

## 5. Tuist manifest

### 5.1 `Tuist/ProjectDescriptionHelpers/ProjectSettings.swift`

```swift
import ProjectDescription

public let bundleIdPrefix = "com.hannun.app"
public let hannunOrganizationName = "Hannun"
public let hannunDestinations: Destinations = [.iPhone, .iPad]
public let hannunDeploymentTargets: DeploymentTargets = .iOS("26.4")

public extension SettingsDictionary {
    static var hannunBase: SettingsDictionary {
        [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY": "YES",
            "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
        ]
    }
}

/// 모든 프로젝트가 공유하는 프로젝트 단위 설정.
public let hannunProjectSettings: Settings = .settings(base: .hannunBase)
```

> 프로젝트 설정은 소속 타깃 전체로 내려간다. 단일 프로젝트 시절에는 타깃마다
> `settings: .settings(base: .hannunBase)` 를 붙였지만, 이제 프로젝트 팩토리가 한 번만 건다.

### 5.2 프로젝트 팩토리 — `Project+Module.swift` / `Project+Feature.swift`

두 헬퍼가 `Project` **하나를 통째로** 만든다. 각 모듈의 `Project.swift` 는 이 함수 호출 한 줄이다.

```swift
// Project+Module.swift — 공유 계층 (Core / DesignSystem / Domain / Data / TestSupport)
public func moduleProject(
    name: String,
    bundleIdSuffix: String,
    resources: ResourceFileElements? = nil,
    dependencies: [TargetDependency] = [],
    additionalSettings: SettingsDictionary = [:],
    includesTests: Bool = false,
    testDependencies: [TargetDependency] = []
) -> Project
```

```swift
// Project+Feature.swift — 탭 하나
public func featureProject(
    name: String,
    bundleIdSuffix: String,
    extraDependencies: [TargetDependency] = [],
    includesTests: Bool = false,
    testDependencies: [TargetDependency] = []
) -> Project
```

| 항목 | 규칙 |
|---|---|
| product | `.staticFramework` 고정 (테스트는 `.unitTests`) |
| sources | `Sources/**` (모듈 디렉터리 기준) |
| 테스트 sources | `Tests/**`, 타깃명 `{name}Tests` |
| bundleId | 모듈 `com.jeong.hannun.{suffix}` / Feature `com.jeong.hannun.feature.{suffix}` |
| Feature 의존성 | `HannunDomain` · `HannunDesignSystem` · `HannunCore` **고정** |

> `featureProject` 가 Feature 의 의존성을 한 곳에 고정하므로, 실수로 `HannunData` 나
> 다른 Feature 를 끼워 넣는 일이 구조적으로 막힌다.

> `testDependencies` 에는 **테스트 코드가 직접 `import` 하는 모듈을 전부** 적는다.
> 대상 모듈을 통해 전이적으로 링크되더라도 `make inspect` 가 암묵적 의존성으로 잡는다 (§8).

### 5.3 `Workspace.swift`

```swift
import ProjectDescription

let workspace = Workspace(
    name: "Hannun",
    projects: [
        ".",
        "Modules/*",
        "Features/*",
    ]
)
```

glob 이라 **새 모듈은 디렉터리에 `Project.swift` 만 두면 자동 등록**된다 — 이 파일은 고치지 않는다.
(`make generate` 가 `Project.swift` 없는 모듈 디렉터리를 먼저 잡아준다.)

스킴은 전부 Tuist 자동 생성이다. 타깃마다 동명 스킴이 생기고, 전 프로젝트의 타깃·테스트를
한 번에 도는 **`Hannun-Workspace`** 스킴이 함께 생긴다 (`make test-all` 이 이걸 쓴다).
프로젝트 단위 스킴으로는 다른 프로젝트의 테스트 타깃을 `testAction` 에 넣을 수 없으므로,
전체 테스트 스킴을 손으로 유지하지 않는다.

### 5.4 루트 `Project.swift` — 앱 셸만

```swift
let project = Project(
    name: "Hannun",
    organizationName: hannunOrganizationName,
    options: .options(defaultKnownRegions: ["ko", "en"], developmentRegion: "ko"),
    settings: .settings(
        base: .hannunBase,
        configurations: [
            .debug(name: .debug, xcconfig: "App/Config/Hannun.debug.xcconfig"),
            .release(name: .release, xcconfig: "App/Config/Hannun.release.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "Hannun",
            destinations: hannunDestinations,
            product: .app,
            bundleId: bundleIdPrefix,
            deploymentTargets: hannunDeploymentTargets,
            infoPlist: .file(path: "App/Resources/Info.plist"),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/Assets.xcassets"],
            entitlements: .file(path: "App/Config/Hannun.entitlements"),
            dependencies: [
                .project(target: "NetWorthFeature", path: .relativeToRoot("Features/NetWorth")),
                .project(target: "PortfolioFeature", path: .relativeToRoot("Features/Portfolio")),
                .project(target: "PerformanceFeature", path: .relativeToRoot("Features/Performance")),
                .project(target: "JournalFeature", path: .relativeToRoot("Features/Journal")),
                // 구현체를 아는 유일한 지점
                .project(target: "HannunData", path: .relativeToRoot("Modules/Data")),
                // DIContainer·ErrorHandler 직접 사용
                .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
            ]
        ),
    ]
)
```

### 5.5 모듈별 `Project.swift`

호출 한 줄이 곧 모듈 정의다. 전문은 각 파일 참고.

```swift
// Modules/Core/Project.swift — 잎 노드
let project = moduleProject(name: "HannunCore", bundleIdSuffix: "core", includesTests: true)
```

```swift
// Modules/DesignSystem/Project.swift — 리소스 보유 (Bundle.module 접근자 생성)
let project = moduleProject(
    name: "HannunDesignSystem",
    bundleIdSuffix: "designsystem",
    resources: ["Resources/**"],
    dependencies: [.project(target: "HannunCore", path: .relativeToRoot("Modules/Core"))]
)
```

```swift
// Modules/Data/Project.swift — 테스트가 TestSupport 를 직접 import 한다
let project = moduleProject(
    name: "HannunData",
    bundleIdSuffix: "data",
    dependencies: [
        .project(target: "HannunDomain", path: .relativeToRoot("Modules/Domain")),
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "HannunCore", path: .relativeToRoot("Modules/Core")),
        .project(target: "HannunTestSupport", path: .relativeToRoot("Modules/TestSupport")),
    ]
)
```

```swift
// Features/Portfolio/Project.swift — 의존성 3종은 팩토리가 고정한다
let project = featureProject(
    name: "PortfolioFeature",
    bundleIdSuffix: "portfolio",
    includesTests: true
)
```

> **리소스 번들 이름이 바뀐다.** Tuist 가 만드는 번들명은 `{프로젝트}_{타깃}` 이라
> `Hannun_HannunDesignSystem` → `HannunDesignSystem_HannunDesignSystem` 이 됐다.
> `Bundle.module` 접근자가 Derived 에 자동 재생성되므로 코드는 그대로다 (§9.1).

### 5.6 `Tuist.swift`

```swift
import ProjectDescription

let tuist = Tuist(project: .tuist())
```

> **`enforceExplicitDependencies` 는 Tuist 4.202.6 에서 deprecated 다.** 대신
> `tuist inspect dependencies --only implicit`(= `make inspect`)를 CI·로컬 검증 단계로 돌린다.
> generate 시점이 아니라 별도 명령이므로 §8 체크리스트와 `.github/workflows` 에 넣어야 실효가 있다.

### 5.7 외부 의존성 — 없음

**`Tuist/Package.swift` 를 두지 않는다.** 네트워크를 `URLSession` + actor 로 직접 구현하면서
외부 SPM 의존성이 0개가 됐고, 그 결과:

- `tuist install` 단계가 사라진다. `Makefile` 의 `install` 타깃은 `Tuist/Package.swift` 가
  있을 때만 `tuist install` 을 부르고, 없으면 건너뛴다.
- `Tuist/Package.resolved` 를 커밋할 일이 없다. 고정할 버전 파일은 `mise.toml` 하나뿐이다(§7.1).
- **전 타깃이 Swift 6 language mode + `complete` 를 유지한다.** Moya 15는 `SWIFT_VERSION 5.0` +
  `strict-concurrency=minimal` 로 낮춰야 빌드됐다 — 그 예외가 통째로 없어진다.

나중에 외부 패키지가 필요해지면 `Tuist/Package.swift` 를 새로 만들고 `packageSettings.targetSettings`
로 해당 패키지만 설정을 완화한다. 프로젝트 타깃 쪽 설정은 건드리지 않는다.

## 6. 테스트 타깃

설계 문서 §9(테스트 전략) — "핵심 계산 로직은 단위 테스트, UI는 실기기 수동 확인" 을 타깃으로 옮긴 결과.
**테스트는 전부 Swift Testing(`import Testing`)으로 작성한다** — 상세 규칙은 §6.2.

| 테스트 타깃 | 필수 검증 대상 |
|---|---|
| `HannunDomainTests` | **YTD 수익률(입출금 제외 로직)**, KRW↔USD 환산, 카테고리 소계 합산, 스냅샷 소급 계산 |
| `HannunDataTests` | KIS·업비트 DTO 디코딩, 캐시 TTL(15분) 만료 판정, 조회 실패 시 마지막 성공값 폴백, 전송 에러·상태 코드→`AppError` 매핑, 401 재시도 시퀀스 |
| `HannunCoreTests` | `Money` 연산·반올림, 포매터(tabular·통화기호 위계) |
| `PortfolioFeatureTests` | `PF-5`/`PF-6` 입출금 변경 시 파생값 재계산, Loadable 상태 전이 |
| `PerformanceFeatureTests` | `PM-2` 데이터 1건 이하 분기, `PM-4` 벤치마크 일부 실패 시 나머지 표시 |

`NetWorthFeature`·`JournalFeature`는 ViewModel 로직이 얇아(단순 조회·바인딩) 초기에는 테스트 타깃을
만들지 않는다. 계산이 ViewModel로 새어 나오면 그때 추가한다.

### 6.1 `StubURLProtocol` — 네트워크 없는 테스트

`URLProtocol` 서브클래스로 요청을 가로채 미리 정한 응답을 돌려준다. **프로덕션 코드에 스터빙
API를 심지 않는다** — 네트워크 계층은 테스트의 존재를 모르고, `URLSession` 을 주입받을 뿐이다.

```swift
// HannunTestSupport/StubURLProtocol.swift — 핵심만
public final class StubURLProtocol: URLProtocol {
    public typealias Handler = @Sendable (URLRequest) throws -> StubResponse

    private static let sessionIDHeader = "X-Hannun-Stub-Session"
    private static let handlers = Mutex<[String: Handler]>([:])

    /// 스텁이 걸린 세션을 만든다. 세션마다 고유 키를 쓰므로 병렬 테스트에 안전하다.
    public static func makeSession(handler: @escaping Handler) -> URLSession {
        let sessionID = UUID().uuidString
        handlers.withLock { $0[sessionID] = handler }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [sessionIDHeader: sessionID]
        return URLSession(configuration: configuration)
    }
}
```

**핸들러를 세션마다 따로 보관하는 것이 핵심**이다. `URLProtocol` 은 클래스 메서드로만 후킹
지점을 주므로 등록부가 static 일 수밖에 없는데, Swift Testing은 **기본 병렬 실행**이라
(§6.2) 단일 static 핸들러를 쓰면 테스트끼리 서로의 응답을 덮어쓴다. 세션 설정에 UUID를
심어 그 키로 조회하면 병렬로 돌아도 간섭이 없다. 등록부 자체는 `Synchronization.Mutex`
(iOS 18+)로 보호한다 — strict concurrency 하에서 static 가변 상태를 쓰는 유일한 방법이다.

핸들러가 `URLRequest` 를 그대로 받으므로 **요청 검증도 같은 자리에서 한다** — 어떤 쿼리로
몇 번 호출됐는지, 인증 헤더가 실렸는지를 응답을 만들면서 함께 확인할 수 있다.

`HannunDataTests`의 축:

| 검증 | 방법 |
|---|---|
| 정상 응답 → DTO → 도메인 값 변환 | `.json(픽스처)` 반환 |
| 캐시 히트 시 네트워크 미호출 | 핸들러 호출 횟수를 `Mutex<Int>` 로 카운트 |
| API 실패 시 캐시 폴백 + `StaleBadge` 근거 데이터 | 첫 호출은 성공, 이후 `statusCode: 429` 로 전환 |
| TTL 만료 판정 | `QuoteCache(now:)` 에 테스트 시계 주입 — `sleep` 없이 시간을 감는다 |
| 401 재시도 시퀀스 | `RequestAuthorizing` 스파이 actor 로 `invalidate()` 호출 횟수 관찰 |

`HannunTestSupport` 는 `Foundation` 만 있으면 되므로 **외부 의존성이 필요 없다**.

### 6.2 Swift Testing 규칙

**의존성 추가가 필요 없다.** Swift Testing은 Xcode 16+ / Swift 6 toolchain에 포함되어 있어
`Tuist/Package.swift`에 아무것도 넣지 않는다. §5.2의 팩토리가 `includesTests: true` 일 때 만드는
테스트 타깃(`product: .unitTests`)에서 `import Testing` 이 바로 동작한다. XCTest와 한 타깃에 공존 가능하지만,
**신규 테스트는 예외 없이 Swift Testing으로 작성한다.**

| XCTest | Swift Testing |
|---|---|
| `class XCTestCase` | `struct` / `final class` + `@Suite` |
| `func testXxx()` | `@Test func xxx()` |
| `setUp()` / `tearDown()` | `init()` / `deinit` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTUnwrap(x)` | `try #require(x)` |
| `XCTAssertThrowsError` | `#expect(throws: AppError.self) { … }` |
| 반복 케이스마다 함수 복제 | `@Test(arguments:)` 파라미터화 |

#### ⚠️ 기본 병렬 실행 — 공유 상태가 있으면 깨진다

Swift Testing은 **같은 프로세스 안에서 테스트를 병렬로 실행한다.** XCTest의 순차 실행을 전제로
짜면 간헐적 실패가 난다. 이 프로젝트에서 실제로 걸릴 지점 3곳:

| 공유 상태 | 조치 |
|---|---|
| SwiftData `ModelContainer` | **정적/공유 컨테이너를 만들지 않는다.** suite `init()` 에서 인메모리 컨테이너를 매 테스트 인스턴스마다 새로 생성 (Swift Testing은 테스트별로 suite를 새로 만든다) |
| `QuoteCache` (15분 TTL) | 인스턴스를 주입받는 구조로 설계. 싱글턴으로 두면 `@Suite(.serialized)` 필수 |
| `KISTokenStore` (Keychain) | Keychain은 프로세스 전역이라 병렬 시 서로 덮어쓴다 → **`@Suite(.serialized)` 강제** |

```swift
// Modules/Data/Tests/KISTokenStoreTests.swift
@Suite(.serialized)   // Keychain 공유 — 병렬 금지
struct KISTokenStoreTests { … }
```

#### 계층별 작성 패턴

**Domain — 파라미터화가 가장 크게 먹히는 곳.** YTD·환산 같은 계산은 케이스 표가 곧 테스트다.

```swift
// Modules/Domain/Tests/CalculateYTDReturnUseCaseTests.swift
import Testing
import HannunCore
@testable import HannunDomain

struct CalculateYTDReturnUseCaseTests {
    /// 명세 PM-3: (기말 − 기초 − 순입출금) / 기초
    @Test("YTD 수익률 — 입출금 제외", arguments: [
        // (기초, 기말, 순입출금, 기대 수익률)
        (100_000_000.0, 120_000_000.0,          0.0,  0.20),
        (100_000_000.0, 120_000_000.0, 10_000_000.0,  0.10),  // 입금분 제외
        (100_000_000.0,  90_000_000.0, -5_000_000.0, -0.05),  // 출금분 제외
    ])
    func ytdExcludesCashFlow(
        opening: Double, closing: Double, netFlow: Double, expected: Double
    ) async throws {
        let useCase = CalculateYTDReturnUseCase(…)
        let result = try await useCase.execute(…)
        #expect(abs(result - expected) < 0.0001)
    }

    /// 기초자산 0 → division by zero 방어
    @Test func openingZeroThrows() async throws {
        await #expect(throws: DomainError.insufficientData) { … }
    }
}

/// 카테고리 5종 전수 검증 — CaseIterable 이라 케이스 추가 시 자동 포함
@Test(arguments: AssetCategory.allCases)
func categorySubtotalNeverNegative(_ category: AssetCategory) async throws { … }
```

**Data — `StubURLProtocol`(§6.1) + async/await.**

```swift
import Testing
@testable import HannunData
import HannunTestSupport

@Suite("UpbitClient")
struct UpbitClientTests {
    @Test("여러 마켓을 한 번에 조회한다")
    func fetchesMultipleMarkets() async throws {
        let session = StubURLProtocol.makeSession { _ in .json(Self.tickerJSON) }
        defer { StubURLProtocol.tearDown(session) }

        let prices = try await UpbitClient(session: session)
            .prices(markets: ["KRW-BTC", "KRW-ETH"])

        #expect(prices["KRW-BTC"] == .krw(95_000_000))
    }
}

@Suite("MarketDataRepository")
struct MarketDataRepositoryTests {
    @Test("갱신에 실패하면 마지막 캐시값으로 버틴다")
    func fallsBackToStaleValue() async throws {
        let clock = TestClock()                        // 인스턴스 주입 — 병렬 안전
        let shouldFail = Mutex(false)
        let session = StubURLProtocol.makeSession { _ in
            shouldFail.withLock { $0 }
                ? .json(#"{"error":{"message":"요청 제한"}}"#, statusCode: 429)
                : .json(Self.tickerJSON)
        }
        defer { StubURLProtocol.tearDown(session) }

        let repository = MarketDataRepository(
            upbit: UpbitClient(session: session),
            cache: QuoteCache(timeToLive: 900, now: clock.now)
        )
        _ = try await repository.currentPrice(symbol: "KRW-BTC")

        clock.advance(by: 901)                         // 캐시 만료 + 서버 다운
        shouldFail.withLock { $0 = true }

        // StaleBadge 근거 (명세 §8)
        #expect(try await repository.currentPrice(symbol: "KRW-BTC") == .krw(95_000_000))
    }
}
```

> **`QuoteCache.value(for:)` 는 만료 항목을 지우지 않는다.** §8 폴백이 만료된 값을 다시 꺼내
> 쓰기 때문이다. 여기서 버리면 `staleValue(for:)` 가 항상 nil 이 되어 폴백 자체가 죽는다 —
> 위 테스트가 정확히 그 경로를 잡는다.

**Feature — ViewModel은 `@MainActor`.** `@Observable` ViewModel의 Action 메서드가 `@MainActor` 이므로
suite 자체를 격리한다.

```swift
import Testing
@testable import PortfolioFeature

@MainActor
struct PortfolioViewModelTests {
    @Test("PF-5 입출금 추가 시 Loadable 전이")
    func cashFlowAddTransitionsLoadable() async throws {
        let viewModel = PortfolioViewModel(container: .mock)
        #expect(viewModel.holdingsState == .idle)
        await viewModel.refreshTapped()
        let holdings = try #require(viewModel.holdingsState.value)
        #expect(!holdings.isEmpty)
    }
}
```

#### 스킴 설정

스킴은 손으로 선언하지 않는다(§5.3). Tuist 가 자동 생성하는 `Hannun-Workspace` 스킴의 `testAction`
이 전 프로젝트의 테스트 타깃을 포함하고, Swift Testing 타깃도 그대로 인식한다. 새 테스트 타깃을
추가해도 스킴을 손볼 일이 없다.

## 7. 빌드 명령

### 7.1 툴체인 — mise로 버전 고정 (완료)

Tuist는 **mise로 관리하고 버전을 프로젝트에 고정**한다. 저장소 루트의 `mise.toml` 이 단일 진실이다.

```toml
# mise.toml (커밋한다)
[tools]
tuist = "4.202.6"
```

```bash
# 신규 머신 세팅 — mise.toml 의 버전이 그대로 설치된다
mise install

# 이미 세팅된 머신에서 버전만 올릴 때
mise use tuist@<안정판 버전>
```

> ⚠️ **`tuist@latest` 를 쓰지 않는다.** mise의 aqua 백엔드는 프리릴리스를 걸러내지 않아
> `mise latest tuist` 가 canary 빌드(예: `4.204.0-canary.5`)를 반환한다. `@latest` 로 설치하면
> canary가 깔린다. 버전 확인 시에도 안정판만 추려야 한다:
> `mise ls-remote tuist | grep -vE "canary|rc|beta|alpha"`
>
> `brew install tuist` 는 머신마다 버전이 갈리므로 이 프로젝트에서는 쓰지 않는다.

`mise` 가 셸에 activate 돼 있지 않으면 `tuist` 가 PATH에 없다. 그 경우 `mise x -- tuist ...` 로
실행하거나 셸 프로필에 `eval "$(mise activate zsh)"` 를 추가한다.

### 7.2 프로젝트 명령

```bash
# 프로젝트 생성
# tuist install 은 외부 SPM 의존성이 없어 불필요하다 (§5.7)
tuist generate          # Workspace.swift 기준으로 전 프로젝트 생성 + Xcode 열기
tuist generate --no-open

# 빌드 / 테스트
tuist build Hannun
tuist test Hannun-Workspace   # 전 프로젝트 테스트 (자동 생성 스킴)

# 검증 / 유지보수
tuist graph --format png    # 의존성 그래프로 §3 위반 육안 확인
tuist edit                  # manifest 를 Xcode 에서 타입 체크
tuist clean
```

### 7.3 Makefile — 모듈 단위 빌드/테스트 래퍼 (완료)

위 명령을 매번 손으로 치지 않도록 저장소 루트에 `Makefile` 을 둔다. 모든 `tuist` 호출은
`mise exec -- tuist` 로 감싸므로 셸 activate 여부와 무관하게 `mise.toml` 의 4.202.6 이 쓰인다.

```bash
make bootstrap        # 최초 1회: mise install + tuist 버전 확인
make generate         # tuist generate --no-open
make build-domain     # HannunDomain 모듈만 빌드
make test-domain      # HannunDomain 모듈 테스트
make test-all         # Hannun-Workspace 스킴 — 전 프로젝트의 테스트 타깃 5종
make help             # 전체 타깃 + 모듈 ↔ 스킴 매핑 표
```

| 그룹 타깃 | 대상 |
|---|---|
| `build-modules` | 앱 제외 전 모듈 — L1(`core`,`design`) → L3(`domain`) → L4(`data`) → Feature 4종 → `testsupport` 순 |
| `build-features` | Feature 4종만 |
| `build-all` | `build-modules` + `build-app` |
| `test-modules` | 테스트 타깃이 있는 5개 모듈을 순차 실행 (공용 스킴 없이 모듈별 격리 확인용) |
| `ci` | `install` → `generate` → `build-all` → `test-all` |

`build-<모듈>` / `test-<모듈>` 은 패턴 규칙이고, 모듈 약칭 ↔ 스킴 매핑은 §2 타깃 목록을 그대로 옮긴
것이다 (`core`/`design`/`domain`/`data`/`networth`/`portfolio`/`performance`/`journal`/
`testsupport`/`app`). 오타나 테스트 타깃이 없는 모듈은 xcodebuild 를 띄우기 전에 걸러 안내한다.

오버라이드 변수: `SCHEME`, `DESTINATION`(기본 `platform=iOS Simulator,name=iPhone 17 Pro`),
`CONFIGURATION`, `DERIVED_DATA`(비우면 Xcode 공용 DerivedData), `FILTER`(→ `-only-testing:`,
Swift Testing 스위트 단위 실행). `xcbeautify` 가 있으면 자동으로 로그를 포매팅하고 없으면 원본 출력을
쓴다 — 파이프에서 실패를 삼키지 않도록 `.SHELLFLAGS` 에 `-o pipefail` 을 준다.

> **전제 조건**: 모듈별 타깃도 `test-all` 도 Tuist 자동 생성 스킴에 의존한다 — 타깃마다 동명 스킴,
> 워크스페이스마다 `Hannun-Workspace`. 따라서 `Tuist.swift` 의 `generationOptions` 에
> **`disableAutogeneratedSchemes` 를 넣지 않는다.**
>
> `Workspace.swift` / 루트 `Project.swift` 가 없거나, `Modules/*`·`Features/*` 중 `Project.swift`
> 가 빠진 디렉터리가 있으면 각 타깃이 실패 대신 안내를 출력한다 (§12 참고). 후자는 워크스페이스
> glob 에서 조용히 누락되는 사고를 막으려는 검사다.

`.gitignore` 에 추가할 항목:

```
*.xcodeproj
*.xcworkspace
Derived/
.tuist/
Tuist/.build/
.derived-data/
graph.png
graph.dot
App/Config/Hannun.debug.xcconfig
App/Config/Hannun.release.xcconfig
```

> 생성물(`.xcodeproj`/`.xcworkspace`)은 커밋하지 않는다 — Tuist를 쓰는 이유 자체가 프로젝트 파일
> 충돌 제거다. 신규 클론 후 첫 명령은 `mise install && tuist generate` (= `make bootstrap`).
>
> **커밋하는 버전 고정 파일은 `mise.toml`(Tuist 버전) 하나뿐이다.** 외부 SPM 의존성이 없어
> `Tuist/Package.resolved` 가 존재하지 않는다(§5.7).

## 8. CLAUDE.md 반영 필요 사항

`CLAUDE.md` 의 **"빌드 명령 (요약)" 섹션은 반영 완료**다 — Makefile 기준 명령, 매니페스트 구성
(`Workspace.swift` + 모듈별 `Project.swift`), `make inspect` 주의를 담았다.
원본 `tuist` 명령은 §7.2, 모듈 약칭 매핑은 §7.3 에 있다.

**절대 규칙에 추가를 검토할 항목 2개** — 둘 다 위반 시 조용히 깨지는 종류다.

1. **테스트는 Swift Testing으로만 작성** (`import Testing`, XCTest 신규 작성 금지) — §6.2.
   병렬 실행이 기본이므로 공유 상태(`ModelContainer`·Keychain·캐시)는 인스턴스 주입 또는
   `@Suite(.serialized)` 를 쓴다.
2. **네트워크 타입은 `HannunData` 밖으로 나가지 않는다** — §3 봉인 규칙 3가지.
   `Endpoint`·`NetworkClient`·DTO는 전부 `internal` 이고, `public` 인 것은 Repository 구현체뿐이다.

또한 `docs/claude/architecture.md` §Feature 폴더 구조는 `Features/{Feature}/{Presentation,Domain,Data}`
로 되어 있었는데, 이 프로젝트에서는 Domain/Data가 공유 모듈이므로(§10.1) 실제 구조는
`Features/{Feature}/Sources/{Views,ViewModels,Components,Router}` 다 —
**architecture.md를 §4.3의 실제 구조로 고쳐 반영 완료**다. Feature 가 Presentation 만 담는 이유와
UseCase 가 `Modules/Domain` 에 있는 이유도 그쪽에 함께 적었다.

## 9. 구현 시 주의사항

### 9.1 static framework 리소스 접근

`HannunDesignSystem`은 컬러 Asset Catalog을 가진 static framework다. `Color("brand")` 는 main
bundle을 찾으므로 **반드시 번들을 명시**한다.

```swift
public extension Color {
    static let brand = Color("brand", bundle: .module)   // Tuist 가 생성하는 번들 접근자
}
```

토큰 정의는 §2.1 표의 라이트/다크 값을 Asset Catalog의 Any/Dark appearance로 넣고, Swift 쪽은
위 형태의 얇은 래퍼만 둔다. 하드코딩 hex를 코드에 박지 않는다.

### 9.2 SwiftData + CloudKit 스키마 제약 (엔티티 설계에 영향)

CloudKit 동기화를 켜면 SwiftData 스키마에 다음 제약이 강제된다. "필수값"을 모델 제약으로 옮기면
런타임에 스키마 검증 실패로 크래시하므로, 설계 문서 §4 엔티티 표는 이 제약에 맞춰
**모델 기본값 + 계층 검증**으로 다시 쓰였다(§11-④).

| 제약 | 영향받는 필드 |
|---|---|
| 모든 프로퍼티는 optional 이거나 기본값 필수 | `Holding.ticker`, `JournalEntry.title` 등 "필수값"으로 명세된 필드 → **모델은 기본값, 필수 검증은 UseCase/ViewModel 계층에서** |
| `@Attribute(.unique)` 사용 불가 | 티커 중복 방지를 unique 제약으로 못 함 → UseCase에서 조회 후 판정 |
| 관계는 양방향·optional 필수 | `JournalEntry` ↔ `Holding` 연결(0개 이상) → 양쪽에 inverse 관계 선언 |

### 9.3 Swift 6 strict concurrency + SwiftData

- `ModelContainer` 생성·`ModelContext` 접근은 `@MainActor` 컨텍스트에서 수행하고, 백그라운드
  작업(스냅샷 소급 계산 `PM-1`)은 `@ModelActor` 를 쓴다.
- `@Model` 클래스는 `Sendable` 이 아니다. Repository 경계에서 **엔티티를 그대로 반환하지 말고
  `HannunCore`의 값 타입(`Money` 등)으로 변환**해 넘긴다. 이게 Domain↔Data 경계를 지키는 실질적 장치다.

### 9.4 `Endpoint` 작성 규칙

요청을 **선언**만 하는 프로토콜이다. 기본 구현이 `URLRequest` 조립까지 맡으므로 각 엔드포인트는
자기와 다른 부분만 적는다.

```swift
// Modules/Data/Sources/Network/Endpoint.swift
protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    var authentication: EndpointAuthentication { get }
}

extension Endpoint {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
    var body: Data? { nil }
    var authentication: EndpointAuthentication { .none }

    /// 선언을 실제 요청으로 조립한다.
    /// 퍼센트 인코딩은 `URLComponents` 가 처리하므로 직접 문자열을 이어붙이지 않는다.
    func makeRequest() throws -> URLRequest { … }
}
```

**`authentication` 을 엔드포인트 자신이 선언하는 것**이 이 설계의 핵심이다. 외부 API가 둘이고
인증 체계가 서로 다르므로(업비트 Quotation은 무인증, KIS는 Bearer + 앱키 헤더), "이 요청에 인증이
필요한가"를 별도 정책 객체가 아니라 선언부가 들고 있어야 분기가 한 곳에 모인다.

```swift
enum EndpointAuthentication: Equatable, Sendable {
    case none               // 업비트 Quotation API (§11.1)
    case kisAccessToken     // KIS Bearer + 앱키·앱시크릿 헤더 (§11.2)
}
```

업비트는 이게 전부다 — 기본 구현 덕에 `baseURL`/`path`/`queryItems` 세 개만 적으면 끝난다.

```swift
// Modules/Data/Sources/Upbit/UpbitEndpoint.swift
enum UpbitEndpoint: Endpoint {
    case ticker(markets: [String])

    private static let host = URL(string: "https://api.upbit.com")!

    var baseURL: URL { Self.host }
    var path: String { switch self { case .ticker: "/v1/ticker" } }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .ticker(markets):
            [URLQueryItem(name: "markets", value: markets.joined(separator: ","))]
        }
    }
}
```

KIS는 엔드포인트마다 `tr_id` 헤더가 다른데, 그 분기를 `headers` switch 하나가 흡수한다.
`appkey`/`appsecret` 은 토큰 발급 케이스의 associated value로 받는다 — 선언부가 시크릿 저장소를
직접 읽지 않게 해서 테스트에서 더미 키로 스텁이 가능하다.

**Mock 픽스처는 선언부에 두지 않는다.** Moya의 `sampleData` 는 `TargetType` 필수 멤버라
`#if DEBUG` 로 통째로 감쌀 수 없어 릴리스 빌드에 빈 껍데기가 남았다. 지금은 픽스처가 테스트
코드 안에만 있으므로 CLAUDE.md 절대규칙 3이 구조적으로 지켜진다.

### 9.5 `NetworkClient` actor + Swift 6 strict concurrency

`URLSession.data(for:)` 가 이미 async 이고 `Data`·`URLResponse` 둘 다 `Sendable` 이라
**continuation 브리지도, `@preconcurrency import` 도 필요 없다.** actor를 쓰는 이유는
Sendable 회피가 아니라 **401 재시도 시퀀스를 직렬화**하기 위해서다.

```swift
// Modules/Data/Sources/Network/NetworkClient.swift

/// 요청에 인증 정보를 채워 넣는 쪽. 업비트처럼 인증이 없는 API 는 authorizer 없이 쓴다.
protocol RequestAuthorizing: Sendable {
    func authorize(_ request: URLRequest) async throws -> URLRequest
    func invalidate() async
}

actor NetworkClient {
    private let session: URLSession
    private let authorizer: (any RequestAuthorizing)?
    private let maxRetryCount: Int

    func send<Value: Decodable & Sendable>(
        _ endpoint: some Endpoint, as _: Value.Type, decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Value {
        let data = try await data(for: endpoint)
        do { return try decoder.decode(Value.self, from: data) }
        catch { throw AppError.decoding("\(Value.self) 응답을 해석하지 못했습니다.") }
    }

    private func perform(_ endpoint: some Endpoint, retryCount: Int) async throws -> Data {
        var request = try endpoint.makeRequest()
        if endpoint.authentication != .none {
            guard let authorizer else { throw AppError.unauthorized }
            request = try await authorizer.authorize(request)
        }
        …
        // 토큰 만료. 한 번만 무효화 후 재시도하고, 그래도 401 이면 재로그인 흐름으로 넘긴다.
        if httpResponse.statusCode == 401, endpoint.authentication != .none {
            guard retryCount < maxRetryCount else { throw AppError.unauthorized }
            await authorizer?.invalidate()
            return try await perform(endpoint, retryCount: retryCount + 1)
        }
        …
    }
}
```

> **actor 는 재진입 가능하다.** `await` 마다 격리가 풀리므로 요청 자체가 직렬화되지는 않는다 —
> 배치 조회가 서로를 막지 않는 건 그 덕이지만, "actor니까 순서가 보장된다"고 가정하면 안 된다.
> 실제 중복 방지는 `KISTokenProvider` 가 진행 중인 발급 `Task` 를 저장해 후속 호출을 **합류**시키는
> 방식으로 한다(§9.6).

전송 에러·상태 코드 → `AppError` 매핑은 **`HannunData` 에 확장으로** 둔다. `AppError` 는
`HannunCore` 소속이고 Core는 `URLSession` 을 모르기 때문이다(§3 봉인 규칙 2).

```swift
// Modules/Data/Sources/Network/AppError+Transport.swift
extension AppError {
    /// URLSession 이 던진 에러를 사용자에게 보일 문구로 옮긴다.
    init(transport error: any Error) {
        if error is CancellationError { self = .network("요청이 취소되었습니다."); return }
        guard let urlError = error as? URLError else { … }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            self = .network("인터넷 연결을 확인해주세요.")   // → 캐시 폴백 + StaleBadge (명세 §8)
        case .timedOut:
            self = .network("서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요.")
        …
        }
    }

    /// 실패 응답을 옮긴다. 서버가 준 문구가 있으면 그쪽을 우선한다.
    init(statusCode: Int, data: Data?) { … }   // 401 → .unauthorized, 429 → 호출 제한 안내
}
```

`serverMessage(from:)` 가 KIS의 `msg1` 과 업비트의 `error.message` 를 둘 다 읽는다 — 두 API가
에러 본문 모양만 다르고 역할이 같아서 한 함수로 흡수했다.

**주의:** 네트워크 실패가 `Loadable.failed` 로 바로 가는 게 아니라 **캐시 폴백 경로**로 가야 한다.
명세 §8은 "네트워크 없음 시 마지막 성공값 + 갱신 실패 배지"를 요구하므로, `QuoteCache` 히트가 있으면
`MarketDataRepository` 가 에러를 삼키고 stale 데이터를 반환한다. 에러 전파는 캐시도 비어 있을 때만.

### 9.6 KIS 인증 — `RequestAuthorizing` 구현

토큰 주입·갱신은 `RequestAuthorizing` 뒤에 두어 `NetworkClient` 가 인증 방식을 모르게 한다.
`KISTokenProvider`(actor)가 이 프로토콜을 구현하고, `KISTokenStore`(actor)가 Keychain을 감싼다.

```swift
actor KISTokenProvider: RequestAuthorizing {
    private var issueTask: Task<KISToken, any Error>?   // 진행 중인 발급 요청

    func authorize(_ request: URLRequest) async throws -> URLRequest { … }
    func invalidate() async { … }
}
```

- **`invalidate()` 는 비동기 프로토콜 메서드다.** Moya의 `PluginType.prepare` 는 동기라 여기서
  재발급이 불가능했는데, 그 제약이 사라졌다.
- **동시 발급 요청을 하나로 합류시킨다.** 진행 중인 `Task` 를 저장해 두고 후속 호출은 그 결과를
  `await` 한다. 화면 3개가 동시에 401을 받아도 토큰 요청은 1회다.
- **KIS는 refresh token을 주지 않는다**(명세 §11.2). 만료 시 `POST /oauth2/tokenP` 로 재발급이며,
  응답의 `expires_in` 으로 **만료 전에 미리 갱신**해 401 왕복 자체를 줄인다.

### 9.7 KIS 시크릿 관리

- `appkey`/`appsecret` → xcconfig(gitignore) → Info.plist → 런타임 주입 → `KISTarget.issueToken` 인자
- 발급된 access token → **Keychain**(`KISTokenStore`). `UserDefaults` 금지
- 토큰 갱신 로직은 `HannunData/Remote/KIS` 안에 캡슐화. Domain·Feature는 인증의 존재를 모른다

## 10. 설계 판단 근거와 대안

### 10.1 왜 Feature별 Domain/Data 타깃을 만들지 않았나

`docs/claude/architecture.md` 는 원래 Feature마다 Presentation/Domain/Data 3계층을 두는 구조를
기술했다(지금은 §4.3 의 실제 구조로 갱신됐다 — §8). 이를 타깃으로 옮기면 12개 Feature 타깃 +
공유 모듈이 되는데, 이 앱에서는 다음 이유로 성립하지 않는다.

1. **단일 SwiftData 스키마.** 엔티티 5종은 하나의 `ModelContainer`/schema에 등록된다. Feature별
   Domain 타깃으로 쪼개면 스키마 정의가 4개 타깃에 흩어지고, 컨테이너를 만드는 App 타깃이 전부를
   다시 참조해야 한다.
2. **탭이 데이터를 교차 참조한다.** `NW-1` 총자산은 Portfolio의 `Holding` 전체가 필요하고,
   `PM-3` YTD는 `Holding` + `CashFlowEvent` + `NetWorthSnapshot`이, `JR-2` 종목 태그는 `Holding`이
   필요하다. Feature별 Data는 곧 Feature↔Feature 의존이 된다.
3. **서버가 없다.** Feature별 Data 분리가 값을 갖는 건 각 Feature가 독립 백엔드/엔드포인트를 가질
   때다. 외부 API는 KIS·업비트 2개뿐이고 둘 다 여러 탭이 공유한다.

**대안(채택 안 함):** Feature별 3타깃 → 타깃 12개 증가, Domain/Data 타깃 대부분이 파일 1~2개.
경계는 폴더로도 충분히 표현되므로 얻는 것보다 generate·빌드 오버헤드가 크다.

### 10.2 왜 `@Model` 엔티티가 Domain에 있나

순수 Clean Architecture는 영속성 프레임워크를 Domain에서 배제하고 Domain에 별도 struct를 둔다.
그러면 엔티티 5종 × (모델 + DTO + 양방향 매핑)이 되는데, 이 앱은 **로컬 SwiftData가 유일한 저장소이고
서버 DTO와의 스키마 협상이 없으므로** 매핑 계층이 순수 비용이다.

- 채택: `@Model` 을 `HannunDomain/Entities` 에 두고 `HannunDomain` 이 `SwiftData` 를 import
- 이때 생기는 제약: Domain 테스트가 SwiftData에 의존 → 인메모리 `ModelContainer`
  (`isStoredInMemoryOnly: true`)를 `HannunTestSupport` 가 제공해 상쇄
- 대안(채택 안 함): 엔티티를 `HannunData` 에 두고 Domain은 struct — 코드량 약 2배, 이득은 이론적 순수성

### 10.3 왜 UseCase가 Feature가 아니라 Domain에 있나

`FetchHoldingsUseCase`(NetWorth+Portfolio 공유), 환율 환산(3개 탭 공유)처럼 다중 Feature가 쓰는
UseCase가 존재한다. Feature에 두면 첫 공유 시점에 Feature↔Feature 의존이 생긴다. Domain에 두고
`UseCases/{탭}` 폴더로 소유권을 표현한다(§4.1).

### 10.4 네트워킹 — Moya 채택에서 직접 구현으로 (2026-07-31 개정)

**초안의 결정과 그 근거** — KIS가 엔드포인트마다 `tr_id` 헤더가 다르므로 `TargetType` 열거의
실익이 크고, `sampleData` + `stubClosure` 로 `URLProtocol` mock 없이 테스트할 수 있다고 봤다.

**뒤집은 이유 3가지.**

1. **레퍼런스 구현이 Moya를 실제로 쓰고 있지 않았다.** 이 설계가 참고한 UMC 프로젝트의
   `MoyaNetworkAdapter` 는 `MoyaProvider` 를 한 번도 호출하지 않는다 — `TargetType` 을 손으로
   `URLRequest` 로 바꾼 뒤 `actor NetworkClient` → `URLSession.data(for:)` 로 넘긴다.
   Moya가 제공한 건 **선언 규약뿐**이었고, 그 규약은 40줄짜리 `Endpoint` 프로토콜로 대체된다.
2. **호출할 API가 적다.** GET 6~7개 + 토큰 발급 POST 1개가 전부다. multipart·업로드·다운로드·
   진행률 같은 Moya의 나머지 기능은 쓸 일이 없다. `Endpoint` 기본 구현 덕에 업비트 엔드포인트는
   실질 3줄이다(§9.4).
3. **Swift 5 다운그레이드가 통째로 사라진다.** Moya 15는 `SWIFT_VERSION 5.0` +
   `strict-concurrency=minimal` 로 낮춰야 빌드됐고, 그 결과 `MoyaProvider`·`Response` 가
   non-Sendable 인 채로 actor 경계에 걸렸다. 직접 구현하면 `URLSession.data(for:)` 가 이미
   async 이고 `Data`·`URLResponse` 가 Sendable 이라 **continuation 브리지도 `@preconcurrency`
   도 필요 없다.**

**초안이 걱정했던 비용은 실제로 발생하지 않았다.**

| 초안의 우려 | 실제 |
|---|---|
| 스터빙 인프라를 직접 만들어야 한다 | `StubURLProtocol` 약 70줄. 오히려 `sampleData` 보다 낫다 — 요청 자체를 검증할 수 있고, mock 픽스처가 프로덕션 타입에 남지 않는다(§6.1) |
| 헤더 분기를 직접 처리해야 한다 | `Endpoint.headers` switch 하나로 같은 일을 한다. `TargetType` 과 형태가 동일하다 |
| 어댑터 40줄보다 코드가 많아진다 | `Endpoint`+`HTTPMethod`+`NetworkClient` 합계가 Moya 어댑터와 비슷하고, 대신 의존성 2개와 Swift 5 예외가 없다 |

**남은 트레이드오프** — 재시도 백오프·요청 로깅·호출량 제한 게이트를 직접 붙여야 한다.
현재는 401 재시도만 구현했고, 나머지는 필요해지는 시점에 `NetworkClient` 안에 넣는다.
호출량 제한은 캐시(§4.2)가 1차 방어선이라 아직 급하지 않다.

**교체 가능성 유지** — §3의 봉인 규칙 3가지를 지키면 전송 계층은 `HannunData` 내부 구현
디테일에 머문다. 나중에 라이브러리를 도입하더라도 수정 범위는 `Network/` 폴더뿐이고,
Domain·Feature·테스트는 손대지 않는다. **이번 전환 자체가 그 봉인이 실제로 동작한다는 증거다** —
Domain·Feature 코드는 한 줄도 바뀌지 않았다.

### 10.5 설계 문서 §3·§7과의 용어 정합

설계 문서 §3은 계층을 `View → ViewModel → Service → SwiftData 모델` 로 적었고, CLAUDE.md는
`View → ViewModel → UseCase → Repository → DataSource` 로 적었다. 이 문서는 **CLAUDE.md 쪽을
채택**하고, 설계 문서의 "Service"는 그중 `MarketDataService`(외부 시세 조회)를 가리키는 것으로 해석해
DataSource 위치에 배치했다. 설계 문서 §3 문구를 CLAUDE.md 용어로 맞추는 편집을 권한다.

설계 문서 §7은 "`MarketDataService` 프로토콜로 추상화, 마지막 조회 결과를 로컬에 캐싱"만 규정하고
구현 수단은 열어 두었다. 이 문서에서 그 자리를 **`Endpoint` 2종 + `NetworkClient` actor +
클라이언트 2종 + `MarketDataRepository`** 로 구체화했다(§4.2). 설계 문서에 별도 수정은 필요 없다 —
프로토콜 경계가 그대로 유지되기 때문이다.

다만 `MarketDataServiceProtocol` 에 **배치 조회 `currentPrices(symbols:)` 를 추가**했다.
두 API 모두 여러 종목을 한 번에 조회할 수 있고(§11.1의 `markets` 파라미터), 호출량 제한이 있는
이상 종목 수만큼 요청을 보내는 단건 API만으로는 부족하다. 조회하지 못한 심볼은 결과에서 빠진다 —
일부 실패가 전체를 무너뜨리지 않게 하려는 선택이고, 명세 §8의 부분 실패 정책과 같은 방향이다.

### 10.6 왜 단일 `Project.swift` 를 버리고 다중 프로젝트 워크스페이스로 갔나 (2026-08-01 개정)

**초안의 결정과 그 근거** — §1은 "단일 `Project.swift` + 다중 타깃"을 택하고, 이유를 "타깃 10개
규모에서 워크스페이스 분리는 generate 시간만 늘린다"로 적었다. 실제로 그 규모에서 generate 는
0.5초 안팎이고, 이 판단 자체는 지금도 틀리지 않았다.

**뒤집은 이유** — 비용이 아니라 **매니페스트를 사람이 다루는 방식**이 문제였다.

1. **한 파일이 모든 모듈의 변경점을 빨아들인다.** DesignSystem 리소스 하나를 추가해도 diff 는
   루트 `Project.swift` 에 찍힌다. 모듈 소유자가 갈리는 상황에서 매니페스트만 항상 충돌 지점이
   되고, 리뷰에서 "이 줄이 어느 모듈 것인지"를 매번 눈으로 찾아야 한다.
2. **새 모듈 추가가 두 곳 편집이다.** 디렉터리를 만들고 루트 매니페스트에 `.module(...)` /
   `.feature(...)` / `.unitTests(...)` 세 줄을 더해야 했다. 지금은 `Modules/*` · `Features/*`
   glob 이라 **디렉터리에 `Project.swift` 를 두면 끝**이다.
3. **경로가 전부 루트 기준이었다.** `sources: ["Modules/Domain/Sources/**"]` 처럼 모듈 안의
   내용을 루트 좌표로 적어야 해서, 모듈을 옮기면 매니페스트의 문자열을 손봐야 했다. 이제
   `Sources/**` · `Tests/**` · `Resources/**` 는 모듈 기준이고, 루트 좌표(`.relativeToRoot`)는
   **모듈을 가로지르는 의존성에만** 남는다 — 경계를 넘는 지점이 문법으로 드러난다.
4. **스킴을 손으로 유지할 필요가 없어졌다.** 단일 프로젝트일 때는 전체 테스트용 `Hannun` 스킴에
   테스트 타깃 5종을 나열했고, 모듈이 늘 때마다 그 목록을 갱신해야 했다. 워크스페이스에는 Tuist 가
   `Hannun-Workspace` 스킴을 자동 생성해 전 프로젝트의 타깃·테스트를 모두 포함시킨다(§5.3).

**레퍼런스** — 사내 UMCApp(`Workspace.swift` + `Core/*` · `Features/*` glob + `Project` 를 반환하는
`coreProject`/`featureProject` 헬퍼)의 매니페스트 구성을 그대로 따랐다. 폴더명만 `Core/` 대신
기존 `Modules/` 를 유지했다 — 바꾸면 `Core/Core` 가 된다.

**단, 레퍼런스의 Feature 3계층 분할은 채택하지 않았다.** UMCApp 의 `featureProject` 는 Feature 당
`{Name}Domain` / `{Name}Data` / `{Name}Presentation` 3타깃을 만든다. Hannun 의 `featureProject` 는
Presentation 하나만 만들고 Domain/Data 는 `Modules/` 에서 공유한다 — **§10.1 의 근거(단일 SwiftData
스키마, 네 탭의 엔티티 교차 참조, 서버 부재)는 프로젝트를 몇 개로 쪼개든 그대로이기 때문이다.**
매니페스트 구성(어떻게 선언하나)과 계층 분할(무엇을 타깃으로 나누나)은 서로 독립적인 결정이고,
이번에 바꾼 것은 앞쪽뿐이다.

**전환 비용** — 실제로 발생한 변화는 리소스 번들 이름 하나뿐이었다. 번들명이 `{프로젝트}_{타깃}`
이라 `Hannun_HannunDesignSystem` → `HannunDesignSystem_HannunDesignSystem` 이 됐고, `Bundle.module`
접근자는 Tuist 가 Derived 에 재생성하므로 코드는 손대지 않았다. 전환 후 `make inspect` 무결점,
`make build-all` 10타깃, `make test-all` 53테스트 모두 통과.

## 11. 미결 사항 (착수 전 확인 필요)

① **배포 타깃 — 해결됨.** **iOS 26.4** 로 확정했다. 설계 문서 §1 타겟의 "iOS 17 이상"을
"iOS 26.4 이상"으로 고치고 확정 근거(UI 스펙이 Liquid Glass·`tabViewBottomAccessory`·
`ConcentricRectangle` 을 전제한다)를 같은 자리에 남겼다. 매니페스트도 이미 같은 값이다 —
`ProjectSettings.swift` 의 `hannunDeploymentTargets = .iOS("26.4")`(§5.1). 이로써 설계 문서·
UI 스펙·CLAUDE.md·매니페스트가 한 값으로 정렬됐고, iOS 17 유지 시 필요했던 UI 스펙
§2.4·§3.1 재작성 논의는 닫힌다.

② **bundle identifier prefix — 해결됨.** Developer 포털에 App ID 를 등록해 확정했다(이슈 #9).

| 항목 | 값 |
|------|-----|
| Team ID (`DEVELOPMENT_TEAM`) | `8B8B4462NV` |
| Bundle ID (explicit) | `com.hannun.app` |
| CloudKit 컨테이너 | `iCloud.com.hannun.app` |

`bundleIdPrefix` 가 곧 앱 번들 ID 이므로 모듈 타깃은 `com.hannun.app.core` ·
`com.hannun.app.feature.portfolio` 형태가 된다(§5.1).
`HannunModelContainer` 와 `Hannun.entitlements` 두 곳이 컨테이너 ID 를 들고 있고, 둘은 항상 같아야
한다. 포털에 먼저 만들어둔 `iCloud.com.jeong.hannun` 은 `iCloud.{bundleId}` 규칙과 어긋나 폐기했다 —
iCloud 컨테이너는 포털에서 삭제할 수 없으므로 목록에는 남지만 App ID 에 연결하지 않는다.

③ **Tuist 툴체인 — 해결됨.** `mise.toml` 에 `tuist = "4.202.6"` 으로 고정하고, §5 manifest를
`tuist generate` + `tuist build` 로 컴파일 검증까지 마쳤다(§7.1). 이 과정에서 확인된 차이 2가지는
문서에 반영했다 — `enforceExplicitDependencies` 는 deprecated 라 `tuist inspect dependencies`
로 대체(§5.6), 리소스 glob은 `Resources/**` 가 아니라 존재하는 디렉터리만 지정해야 한다.

④ **CloudKit 스키마 제약 반영 — 해결됨.** §9.2 제약에 맞춰 설계 문서 §4 엔티티 표를
"필수/null" 대신 **모델 기본값 + 계층 검증**으로 다시 적었다. 필수 입력·중복 방지 규칙을 어느
계층이 판정하는지(ViewModel 인라인 검증 / UseCase 최종 관문)를 같은 절에 표로 두었고,
`@Attribute(.unique)` 를 어떤 엔티티에도 쓰지 않는다는 점과 그 대안(저장 직전 조회 후 갱신/삽입
판정), 관계의 양방향·optional 선언을 §9.2 와 같은 용어로 명시했다. `docs/claude/architecture.md`
의 Feature 폴더 구조 수정도 함께 마쳤다(§8).

⑤ **네트워크 계층 Swift 6 빌드 검증 — 해결됨.** Moya를 제거하면서 초안이 우려했던 3항목
(외부 패키지 버전 호환, `complete` 상속 하 빌드, `@preconcurrency` 로 non-Sendable 억제)이
**전부 무효가 됐다.** 외부 패키지가 없으므로 전 타깃이 `SWIFT_VERSION 6.0` +
`strict-concurrency=complete` + warnings-as-errors 로 빌드된다. 업비트 경로(`Endpoint` →
`NetworkClient` → `UpbitClient` → `QuoteCache` → `MarketDataRepository`)와 그 테스트 28개가
실제로 통과한 상태다.

⑥ **KIS 경로 미구현.** `MarketDataRepository` 는 심볼이 `KRW-` 로 시작하지 않으면
`AppError.validation` 을 던진다. 국내·해외 주식/ETF·지수·환율은 `KISEndpoint` +
`KISTokenStore`/`KISTokenProvider` 를 붙이는 시점에 열린다(§9.6). 업비트로 파이프라인 전체를
먼저 검증한 뒤 인증을 얹는 순서다.

## 12. 착수 순서

| 단계 | 산출물 | 완료 기준 |
|---|---|---|
| M0 | Tuist 스캐폴딩 — §4 디렉터리, §5 manifest(`Workspace.swift` + 프로젝트 10개) | ✅ `make generate && make build-all` 성공, `make inspect` 무결, `tuist graph` 가 §3과 일치 |
| M1 | `HannunCore` + `HannunDesignSystem` — 토큰(§2.1~2.3), Loadable/AppError/DIContainer, 공통 컴포넌트 18종 | 컴포넌트별 `#if DEBUG` 프리뷰가 Feature 없이 렌더 |
| M2 | `HannunDomain` 엔티티·프로토콜 + `HannunData` Persistence | 인메모리 컨테이너로 CRUD 통과, CloudKit 스키마 검증 통과 |
| M3 | `HannunData` Network — `Endpoint`/`NetworkClient` actor, 업비트·KIS 클라이언트, `KISTokenProvider`, 캐시 | `HannunDataTests` 통과(`StubURLProtocol` 기반, §6.1), 오프라인 시 마지막 성공값 폴백 동작, 401 → 토큰 재발급 → 재시도 확인. **업비트 경로는 완료, KIS 미착수(§11-⑥)** |
| M4 | `PortfolioFeature` (`PF-1`~`PF-6`) | 종목 CRUD·입출금 CRUD 실기기 확인. **다른 탭의 데이터 원천이므로 첫 Feature** |
| M5 | `NetWorthFeature` (`NW-1`~`NW-4`) | 총자산·도넛·통화 토글, `NW-4` 탭 간 이동(AppRoute) 동작 |
| M6 | `PerformanceFeature` (`PM-1`~`PM-4`) | YTD·추이·벤치마크. `HannunDomainTests` YTD 케이스 통과 |
| M7 | `JournalFeature` (`JR-1`~`JR-4`) | 일지 CRUD·종목 태그·필터 |

M4를 Portfolio부터 시작하는 이유: `Holding` 입력이 없으면 나머지 3개 탭이 전부 빈 상태만 보여주므로
수동 검증이 불가능하다.
