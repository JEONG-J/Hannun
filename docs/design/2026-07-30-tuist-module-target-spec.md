# Hannun Tuist 모듈-타깃 구성 문서

- 작성일: 2026-07-30
- 상태: 초안 (구현 착수 전 검토 필요)
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
| 프로젝트 형태 | **단일 `Project.swift` + 다중 타깃** (Workspace 다중 프로젝트 아님) | 9개 타깃 규모에서 멀티 프로젝트는 generate 시간·탐색 비용만 늘고, 모듈 경계는 타깃 의존성으로 이미 강제됨 |
| 모듈 분할 축 | **Feature는 Presentation만 분할, Domain/Data는 공유** | SwiftData 스키마가 단일 ModelContainer로 묶이고, 4개 탭이 같은 엔티티를 교차 참조 (§10.1) |
| 타깃 수 | 앱 1 + 공유 5 + Feature 4 = **10** (+ 테스트 5) | |
| product type | 전부 `.staticFramework` (앱만 `.app`) | dylib 로딩 오버헤드 없음. 리소스는 Tuist 번들 접근자로 해결 (§9.1) |
| 네트워킹 | **Moya** (`TargetType` + `MoyaProvider`) | KIS는 엔드포인트마다 `tr_id` 헤더가 달라 타입 안전한 target 열거가 실익이 크고, 스터빙(`sampleData`)이 테스트·프리뷰에 그대로 쓰임 (§10.4) |
| 외부 의존성 | **Moya 1개** (전이 의존성 Alamofire 포함) — `Tuist/Package.swift`로 관리 | SwiftData·Swift Charts는 시스템 프레임워크. Moya는 `HannunData` **단일 타깃만** 링크 (§3) |
| 툴체인 | **Tuist 4.202.6** — `mise.toml` 로 프로젝트 고정 (§7.1) | 머신 간 버전 편차 제거. `tuist@latest` 는 canary를 물어오므로 금지 |
| 테스트 프레임워크 | **Swift Testing** (`import Testing`) — XCTest 신규 작성 금지 | toolchain 내장이라 의존성 0. 파라미터화(`@Test(arguments:)`)가 YTD·환산 케이스 표에 그대로 맞음. 단 **기본 병렬 실행**이라 공유 상태 주의 (§6.2) |
| Swift 버전 | Swift 6 language mode + `SWIFT_STRICT_CONCURRENCY=complete` | 로컬 toolchain Swift 6.3.3 확인 |
| 배포 타깃 | **iOS 26.0** | Liquid Glass / `tabViewBottomAccessory` / `ConcentricRectangle` 필수 (§11-①) |

## 2. 타깃 목록

| # | 타깃 | product | 책임 | 의존 |
|---|---|---|---|---|
| 1 | `Hannun` | `.app` | 엔트리포인트, `RootTabView`, `AppRouter` 실체, **DIContainer 등록**, ModelContainer 주입, Info.plist·entitlements | Feature 4종, `HannunData` |
| 2 | `HannunCore` | `.staticFramework` | 공유 커널 — 값 타입(`Money`/`Currency`/`AssetCategory`), `Loadable`, `AppError`, `ErrorHandler`, `AlertPrompt` 모델, `DIContainer`, 라우팅 프로토콜·`AppRoute`, 포매터 | 없음 |
| 3 | `HannunDesignSystem` | `.staticFramework` | 디자인 토큰(§2.1~2.4), Glass 헬퍼, 공통 컴포넌트 18종, `ErrorView`/`EmptyStateView`, `.alertPrompt(item:)` 모디파이어 | `HannunCore` |
| 4 | `HannunDomain` | `.staticFramework` | SwiftData 엔티티 5종, Repository·Service 프로토콜, UseCase 전체 | `HannunCore` |
| 5 | `HannunData` | `.staticFramework` | Repository 구현체, `ModelContainer` 팩토리(CloudKit), **Moya `TargetType`·Provider·Plugin**, DTO, 시세 캐시 | `HannunDomain`, `HannunCore`, **`.external("Moya")`** |
| 6 | `NetWorthFeature` | `.staticFramework` | `NW-1`~`NW-4` View/ViewModel/Components/Router | Domain, DesignSystem, Core |
| 7 | `PortfolioFeature` | `.staticFramework` | `PF-1`~`PF-6` | 동일 |
| 8 | `PerformanceFeature` | `.staticFramework` | `PM-1`~`PM-4` | 동일 |
| 9 | `JournalFeature` | `.staticFramework` | `JR-1`~`JR-4` | 동일 |
| 10 | `HannunTestSupport` | `.staticFramework` | 테스트 타깃 전용 fake·fixture (`MockMarketDataService`, 인메모리 ModelContainer, 샘플 Holding, **Moya 스터빙 프로바이더**) | `HannunDomain`, `.external("Moya")` |

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

L2   HannunData         ─→ HannunDomain, HannunCore, Moya(external)
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
| **`HannunData` 외 어떤 타깃도 → `Moya`** | 네트워크 라이브러리 교체 가능성을 `MarketDataServiceProtocol` 뒤에 봉인 | `MoyaError`·`Moya.Response`가 ViewModel까지 새어 나가 라이브러리 교체 시 전 계층 수정 |

**Moya 봉인 규칙 3가지** — `.external(name: "Moya")` 는 `HannunData` 타깃에 **단 한 번만** 등장한다.

1. `MoyaError` 는 `HannunData` 경계에서 `HannunCore`의 `AppError` 로 변환한다.
   `AppError` 는 Core에 있고 Core는 Moya를 모르므로, **변환 코드는 `HannunData`에 확장으로 둔다** (§9.5).
2. `Moya.Response` 는 클라이언트 actor 밖으로 내보내지 않는다. actor 내부에서 `Decodable & Sendable`
   DTO로 디코딩한 뒤 그 DTO만 반환한다 (§9.5).
3. `MarketDataServiceProtocol`(Domain) 시그니처에는 Moya 타입이 등장하지 않는다 — 도메인 값 타입만.

`Tuist.swift`의 `enforceExplicitDependencies` 로 암묵적 링크를 컴파일 타임에 차단한다(§8).

### DesignSystem이 도메인 타입을 쓰지 않는 방법

`CategoryDot`·`AmountText`는 `AssetCategory`/`Currency`가 필요한데, 이 값 타입들을
`HannunDomain`이 아니라 **`HannunCore`(공유 커널)** 에 두어 해결한다.

```swift
// HannunCore
public enum AssetCategory: String, CaseIterable, Sendable { case cash, domesticStock, foreignStock, etf, crypto }
public enum Currency: String, Sendable { case krw, usd }
public struct Money: Equatable, Sendable { public let amount: Decimal; public let currency: Currency }

// HannunDesignSystem — Core만 알면 충분
public struct CategoryDot: View { public init(_ category: AssetCategory) { ... } }
```

`@Model` 엔티티(`Holding` 등)는 `HannunDomain`에 남는다. DesignSystem은 엔티티를 절대 보지 않는다.

## 4. 디렉터리 레이아웃

```
Hannun/
├── mise.toml                          # Tuist 버전 고정 (§7.1) — 커밋
├── Tuist.swift                        # 생성 옵션 (구 Tuist/Config.swift)
├── Project.swift                      # 전 타깃 정의
├── Tuist/
│   ├── Package.swift                  # Moya 선언 + PackageSettings (§5.5)
│   ├── Package.resolved               # 버전 고정 — 커밋한다
│   └── ProjectDescriptionHelpers/
│       ├── ProjectSettings.swift      # bundleId prefix, destinations, 공통 settings
│       └── Target+Hannun.swift        # .module / .feature / .unitTests 팩토리
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
│   ├── Core/{Sources,Tests}
│   ├── DesignSystem/{Sources,Resources}
│   ├── Domain/{Sources,Tests}
│   ├── Data/{Sources,Tests}
│   └── TestSupport/Sources
└── Features/
    ├── NetWorth/Sources
    ├── Portfolio/{Sources,Tests}
    ├── Performance/{Sources,Tests}
    └── Journal/Sources
```

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
Remote/
├── KIS/
│   ├── KISTarget.swift             # TargetType — path·method·task·headers(tr_id)
│   ├── KISSampleData.swift         # sampleData 픽스처 (#if DEBUG, §9.4)
│   ├── KISClient.swift             # actor — MoyaProvider 격리 + async 브리지
│   ├── KISTokenStore.swift         # access token → Keychain
│   └── DTO/                        # KISQuoteDTO · KISTokenDTO · KISIndexDTO …
├── Upbit/
│   ├── UpbitTarget.swift
│   ├── UpbitSampleData.swift
│   ├── UpbitClient.swift           # actor
│   └── DTO/
├── Plugins/
│   ├── KISAuthPlugin.swift         # PluginType — 토큰 주입·만료 시 재발급
│   └── LoggerPlugin.swift          # Moya NetworkLoggerPlugin 래핑 (#if DEBUG 만 등록)
├── AppError+Moya.swift             # MoyaError → AppError 변환 (Core 오염 방지, §9.5)
└── CompositeMarketDataService.swift  # MarketDataServiceProtocol 구현 (KIS+업비트 합성)
Cache/
└── QuoteCache.swift                # 15분 TTL, 마지막 성공값 보존 (StaleBadge 근거)
```

KIS와 업비트를 각각 별도 `TargetType`으로 둔다. baseURL·인증 방식·헤더 규칙이 완전히 달라
하나의 enum에 합치면 `task`/`headers` switch가 두 API의 분기를 섞게 된다. 두 클라이언트를
`CompositeMarketDataService` 가 합성해 Domain에는 프로토콜 하나로 보인다.

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

/// TODO: 팀 organization identifier 확정 후 교체 (§11-②)
public let bundleIdPrefix = "com.jeong.hannun"
public let hannunDestinations: Destinations = [.iPhone, .iPad]
public let hannunDeploymentTargets: DeploymentTargets = .iOS("26.0")

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
```

### 5.2 `Tuist/ProjectDescriptionHelpers/Target+Hannun.swift`

```swift
import ProjectDescription

public extension Target {
    /// 공유 계층 모듈 (Core / DesignSystem / Domain / Data / TestSupport)
    static func module(
        name: String,
        path: String,
        hasResources: Bool = false,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: name,
            destinations: hannunDestinations,
            product: .staticFramework,
            bundleId: "\(bundleIdPrefix).\(name.lowercased())",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["\(path)/Sources/**"],
            resources: hasResources ? ["\(path)/Resources/**"] : nil,
            dependencies: dependencies,
            settings: .settings(base: .hannunBase)
        )
    }

    /// Feature 모듈 — 의존성이 항상 동일하므로 팩토리로 고정한다
    static func feature(name: String, path: String) -> Target {
        .module(
            name: name,
            path: path,
            dependencies: [
                .target(name: "HannunDomain"),
                .target(name: "HannunDesignSystem"),
                .target(name: "HannunCore"),
            ]
        )
    }

    /// Swift Testing 전용 타깃. `import Testing` 은 toolchain 내장이라 별도 의존성이 없다 (§6.2)
    static func unitTests(for moduleName: String, path: String) -> Target {
        .target(
            name: "\(moduleName)Tests",
            destinations: hannunDestinations,
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(moduleName.lowercased()).tests",
            deploymentTargets: hannunDeploymentTargets,
            sources: ["\(path)/Tests/**"],
            dependencies: [
                .target(name: moduleName),
                .target(name: "HannunTestSupport"),
            ],
            settings: .settings(base: .hannunBase)
        )
    }
}
```

> `Target.feature`가 Feature의 의존성을 한 곳에 고정하므로, 실수로 `HannunData`를 끼워 넣는 일이
> 구조적으로 막힌다.

### 5.3 `Project.swift`

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "Hannun",
    organizationName: "Hannun",
    options: .options(defaultKnownRegions: ["ko", "en"], developmentRegion: "ko"),
    settings: .settings(
        base: .hannunBase,
        configurations: [
            .debug(name: .debug, xcconfig: "App/Config/Hannun.debug.xcconfig"),
            .release(name: .release, xcconfig: "App/Config/Hannun.release.xcconfig"),
        ]
    ),
    targets: [
        // MARK: - App
        .target(
            name: "Hannun",
            destinations: hannunDestinations,
            product: .app,
            bundleId: bundleIdPrefix,
            deploymentTargets: hannunDeploymentTargets,
            infoPlist: .file(path: "App/Resources/Info.plist"),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            entitlements: .file(path: "App/Config/Hannun.entitlements"),
            dependencies: [
                .target(name: "NetWorthFeature"),
                .target(name: "PortfolioFeature"),
                .target(name: "PerformanceFeature"),
                .target(name: "JournalFeature"),
                .target(name: "HannunData"),        // 구현체를 아는 유일한 지점
            ],
            settings: .settings(base: .hannunBase)
        ),

        // MARK: - Shared
        .module(name: "HannunCore", path: "Modules/Core", dependencies: []),
        .module(name: "HannunDesignSystem", path: "Modules/DesignSystem", hasResources: true,
                dependencies: [.target(name: "HannunCore")]),
        .module(name: "HannunDomain", path: "Modules/Domain",
                dependencies: [.target(name: "HannunCore")]),
        .module(name: "HannunData", path: "Modules/Data",
                dependencies: [
                    .target(name: "HannunDomain"),
                    .target(name: "HannunCore"),
                    .external(name: "Moya"),        // Moya 가 등장하는 유일한 지점 (§3)
                ]),
        .module(name: "HannunTestSupport", path: "Modules/TestSupport",
                dependencies: [
                    .target(name: "HannunDomain"),
                    .external(name: "Moya"),        // 스터빙 프로바이더용 (§6.1) — 테스트 타깃만 링크
                ]),

        // MARK: - Features
        .feature(name: "NetWorthFeature", path: "Features/NetWorth"),
        .feature(name: "PortfolioFeature", path: "Features/Portfolio"),
        .feature(name: "PerformanceFeature", path: "Features/Performance"),
        .feature(name: "JournalFeature", path: "Features/Journal"),

        // MARK: - Tests
        .unitTests(for: "HannunCore", path: "Modules/Core"),
        .unitTests(for: "HannunDomain", path: "Modules/Domain"),
        .unitTests(for: "HannunData", path: "Modules/Data"),
        .unitTests(for: "PortfolioFeature", path: "Features/Portfolio"),
        .unitTests(for: "PerformanceFeature", path: "Features/Performance"),
    ],
    schemes: [
        .scheme(
            name: "Hannun",
            shared: true,
            buildAction: .buildAction(targets: ["Hannun"]),
            testAction: .targets([
                "HannunCoreTests", "HannunDomainTests", "HannunDataTests",
                "PortfolioFeatureTests", "PerformanceFeatureTests",
            ]),
            runAction: .runAction(configuration: .debug, executable: "Hannun")
        ),
    ]
)
```

### 5.4 `Tuist.swift`

```swift
import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        generationOptions: .options(
            enforceExplicitDependencies: true   // §3 금지 간선을 빌드 타임에 차단
        )
    )
)
```

> Tuist 4.x 기준 API다. 로컬에 Tuist가 아직 없으므로(§11-③) 설치 후 `tuist --version` 을 확인하고
> manifest를 `tuist edit` 에서 컴파일 검증한 뒤 확정한다. 버전에 따라 `Tuist.swift` 대신
> `Tuist/Config.swift`, `.target(name:)` 대신 `Target(name:)` 형태일 수 있다.

### 5.5 `Tuist/Package.swift` (Moya 의존성)

Tuist는 이 파일의 `#if TUIST` 블록을 읽어 SPM 패키지를 프로젝트 타깃으로 통합한다. 앱 코드용
`Package.swift`가 아니라 **의존성 선언 전용** 파일이며, 루트가 아니라 `Tuist/` 아래에 둔다.

```swift
// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription
import ProjectDescriptionHelpers

let packageSettings = PackageSettings(
    // 기본값이 .staticFramework 이므로 별도 지정하지 않는다.
    // Moya·Alamofire 를 정적 링크해 dylib 로딩을 없애고 §1 결정과 일관되게 유지한다.
    // SwiftUI 프리뷰에서 외부 모듈 심볼 해결 문제가 발생하면 아래를 켠다:
    //   productTypes: ["Moya": .framework, "Alamofire": .framework]
    productTypes: [:],
    baseSettings: .settings(base: .hannunBase)
)
#endif

let package = Package(
    name: "Hannun",
    dependencies: [
        .package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "15.0.0")),
    ]
)
```

- **Alamofire를 직접 선언하지 않는다.** Moya의 전이 의존성으로 자동 해석된다. 직접 URLSession
  코드를 쓸 일이 생겨도 Moya를 거치도록 하고, Alamofire를 별도 의존성으로 올리지 않는다.
- **RxSwift/ReactiveSwift 서브스펙을 쓰지 않는다.** 이 프로젝트는 async/await + `@Observable` 조합이므로
  리액티브 확장이 필요 없다. `.external(name: "Moya")` 만 링크하면 core만 들어온다.
- `baseSettings`로 외부 패키지에도 프로젝트 공통 설정을 적용하되, **`SWIFT_STRICT_CONCURRENCY`·
  `SWIFT_TREAT_WARNINGS_AS_ERRORS`가 외부 소스에 적용되면 Moya 15가 빌드 실패할 수 있다.**
  실패 시 `packageSettings.targetSettings` 로 Moya·Alamofire만 완화한다:

```swift
    targetSettings: [
        "Moya": .settings(base: [
            "SWIFT_STRICT_CONCURRENCY": "minimal",
            "SWIFT_TREAT_WARNINGS_AS_ERRORS": "NO",
        ]),
        "Alamofire": .settings(base: [
            "SWIFT_TREAT_WARNINGS_AS_ERRORS": "NO",
        ]),
    ]
```

## 6. 테스트 타깃

설계 문서 §9(테스트 전략) — "핵심 계산 로직은 단위 테스트, UI는 실기기 수동 확인" 을 타깃으로 옮긴 결과.
**테스트는 전부 Swift Testing(`import Testing`)으로 작성한다** — 상세 규칙은 §6.2.

| 테스트 타깃 | 필수 검증 대상 |
|---|---|
| `HannunDomainTests` | **YTD 수익률(입출금 제외 로직)**, KRW↔USD 환산, 카테고리 소계 합산, 스냅샷 소급 계산 |
| `HannunDataTests` | KIS·업비트 DTO 디코딩, 캐시 TTL(15분) 만료 판정, 조회 실패 시 마지막 성공값 폴백, `MoyaError`→`AppError` 매핑 |
| `HannunCoreTests` | `Money` 연산·반올림, 포매터(tabular·통화기호 위계) |
| `PortfolioFeatureTests` | `PF-5`/`PF-6` 입출금 변경 시 파생값 재계산, Loadable 상태 전이 |
| `PerformanceFeatureTests` | `PM-2` 데이터 1건 이하 분기, `PM-4` 벤치마크 일부 실패 시 나머지 표시 |

`NetWorthFeature`·`JournalFeature`는 ViewModel 로직이 얇아(단순 조회·바인딩) 초기에는 테스트 타깃을
만들지 않는다. 계산이 ViewModel로 새어 나오면 그때 추가한다.

### 6.1 Moya 스터빙 — 네트워크 없는 테스트

Moya 채택의 실질적 이득 중 하나. `TargetType.sampleData` 에 픽스처를 넣고 `stubClosure` 로
프로바이더를 만들면 **URLSession을 타지 않고** DTO 디코딩과 실패 폴백을 검증할 수 있다.
`URLProtocol` 서브클래싱이나 별도 HTTP mock 서버가 필요 없다.

```swift
// HannunTestSupport
public extension MoyaProvider {
    /// sampleData 로 즉시 응답하는 프로바이더 (§9.4 의 #if DEBUG 픽스처 사용)
    static func stubbed() -> MoyaProvider<Target> {
        MoyaProvider<Target>(stubClosure: MoyaProvider.immediatelyStub)
    }

    /// 네트워크 실패 경로 검증용
    static func failing(_ error: MoyaError) -> MoyaProvider<Target> {
        MoyaProvider<Target>(endpointClosure: { target in
            Endpoint(
                url: URL(target: target).absoluteString,
                sampleResponseClosure: { .networkError(error as NSError) },
                method: target.method,
                task: target.task,
                httpHeaderFields: target.headers
            )
        }, stubClosure: MoyaProvider.immediatelyStub)
    }
}
```

`HannunDataTests`의 두 축:

| 검증 | 사용 |
|---|---|
| 정상 응답 → DTO → 도메인 값 변환 | `MoyaProvider.stubbed()` + `sampleData` |
| API 실패 시 캐시 폴백 + `StaleBadge` 근거 데이터 | `MoyaProvider.failing(.underlying(...))` + 캐시 선점입 |

`HannunTestSupport` 는 이 확장 때문에 Moya를 알아야 한다 → **의존성에 `.external(name: "Moya")` 추가**
(§2 표의 `HannunTestSupport` 항목). 테스트 타깃만 링크하므로 §3의 봉인 규칙 위반이 아니다.

### 6.2 Swift Testing 규칙

**의존성 추가가 필요 없다.** Swift Testing은 Xcode 16+ / Swift 6 toolchain에 포함되어 있어
`Tuist/Package.swift`에 아무것도 넣지 않는다. §5.2의 `Target.unitTests` 팩토리(`product: .unitTests`)가
생성하는 타깃에서 `import Testing` 이 바로 동작한다. XCTest와 한 타깃에 공존 가능하지만,
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

**Data — Moya 스텁(§6.1) + async/await.**

```swift
import Testing
@testable import HannunData
import HannunTestSupport

struct KISClientTests {
    @Test func decodesDomesticQuote() async throws {
        let client = KISClient(provider: .stubbed(), tokenStore: .inMemory())
        let quote = try await client.request(.domesticQuote(ticker: "005930"), as: KISQuoteDTO.self)
        #expect(quote.currentPrice > 0)
    }

    @Test func offlineFallsBackToCache() async throws {
        let cache = QuoteCache()                       // 인스턴스 주입 — 병렬 안전
        await cache.store(…)
        let service = CompositeMarketDataService(
            kis: KISClient(provider: .failing(.underlying(URLError(.notConnectedToInternet), nil)), …),
            cache: cache
        )
        let result = try await service.quote(for: "005930")
        #expect(result.isStale)                        // StaleBadge 근거 (명세 §8)
    }
}
```

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

§5.3의 `.testAction(.targets([...]))` 은 Swift Testing 타깃도 그대로 인식한다. `tuist test Hannun` 이
XCTest·Swift Testing을 모두 실행하므로 명령 변경도 없다.

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
tuist install           # Tuist/Package.swift 의 Moya 해석 — generate 전에 필수
tuist generate          # Hannun.xcworkspace 생성 + Xcode 열기
tuist generate --no-open

# 빌드 / 테스트
tuist build Hannun
tuist test Hannun

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
make test-all         # Hannun 공용 스킴의 testAction (§5.3 의 테스트 타깃 5종)
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

> **전제 조건**: 모듈별 타깃은 Tuist 가 타깃마다 자동 생성하는 스킴에 의존한다. 따라서
> `Tuist.swift` 의 `generationOptions` 에 **`disableAutogeneratedSchemes` 를 넣지 않는다.**
> §5.3 에서 명시적으로 선언하는 `Hannun` 공용 스킴은 자동 생성 스킴과 공존한다.
>
> `Project.swift` / 워크스페이스가 없으면 각 타깃이 실패 대신 "M0 스캐폴딩 필요" 안내를 출력한다
> (§12 참고). 즉 M0 완료 전까지 `make bootstrap` / `doctor` / `help` 만 동작한다.

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
> 충돌 제거다. 신규 클론 후 첫 명령은 항상 `mise install && tuist install && tuist generate`.
>
> **커밋하는 버전 고정 파일 2개** — `mise.toml`(Tuist 버전), `Tuist/Package.resolved`(Moya·Alamofire
> 버전). 둘이 함께 있어야 클론·CI 환경에서 동일한 툴체인 + 동일한 의존성 트리가 재현된다.
> `Tuist/.build/` 는 해석 캐시이므로 무시한다.

## 8. CLAUDE.md 반영 필요 사항

`CLAUDE.md` 의 **"빌드 명령 (요약)" 섹션이 현재 비어 있다.** Makefile 기준 명령
(`make bootstrap` / `make generate` / `make build-<모듈>` / `make test-<모듈>` / `make test-all`)과
이 문서 링크를 채워야 한다. 원본 `tuist` 명령은 §7.2, 모듈 약칭 매핑은 §7.3 에 있다.

**절대 규칙에 추가를 검토할 항목 2개** — 둘 다 위반 시 조용히 깨지는 종류다.

1. **테스트는 Swift Testing으로만 작성** (`import Testing`, XCTest 신규 작성 금지) — §6.2.
   병렬 실행이 기본이므로 공유 상태(`ModelContainer`·Keychain·캐시)는 인스턴스 주입 또는
   `@Suite(.serialized)` 를 쓴다.
2. **Moya는 `HannunData` 밖으로 나가지 않는다** — §3 봉인 규칙 3가지.

또한 `docs/claude/architecture.md` §Feature 폴더 구조는 `Features/{Feature}/{Presentation,Domain,Data}`
로 되어 있는데, 이 프로젝트에서는 Domain/Data가 공유 모듈이므로(§10.1) 실제 구조는
`Features/{Feature}/Sources/{Views,ViewModels,Components,Router}` 다. architecture.md를 수정하거나
"Hannun에서는 §4.3을 따른다"는 주석을 달아야 한다.

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

CloudKit 동기화를 켜면 SwiftData 스키마에 다음 제약이 강제된다. 설계 문서 §4 엔티티 표를 그대로
구현하면 런타임에 스키마 검증 실패로 크래시한다.

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

### 9.4 Moya `TargetType` 작성 규칙

```swift
// Modules/Data/Sources/Remote/KIS/KISTarget.swift
@preconcurrency import Moya   // ← §9.5 참고: Moya 타입의 non-Sendable 경고 차단

enum KISTarget {
    case issueToken(appKey: String, appSecret: String)
    case domesticQuote(ticker: String)
    case overseasQuote(exchange: String, ticker: String)
    case exchangeRate
    case indexQuote(code: String)
}

extension KISTarget: TargetType {
    var baseURL: URL { URL(string: "https://openapi.koreainvestment.com:9443")! }

    var path: String {
        switch self {
        case .issueToken: "/oauth2/tokenP"
        case .domesticQuote: "/uapi/domestic-stock/v1/quotations/inquire-price"
        case .overseasQuote: "/uapi/overseas-price/v1/quotations/price"
        case .exchangeRate, .indexQuote: "/uapi/…"   // 명세 §11.2 참조
        }
    }

    var method: Moya.Method {
        switch self {
        case .issueToken: .post
        default: .get
        }
    }

    /// ⚠️ `Moya.Task` — Swift Concurrency 의 `Task` 와 타입명이 충돌한다.
    /// 이 파일에서 async 코드를 함께 쓰면 반드시 모듈명을 명시할 것.
    var task: Moya.Task {
        switch self {
        case let .issueToken(appKey, appSecret):
            .requestParameters(
                parameters: ["grant_type": "client_credentials",
                             "appkey": appKey, "appsecret": appSecret],
                encoding: JSONEncoding.default
            )
        case let .domesticQuote(ticker):
            .requestParameters(
                parameters: ["FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": ticker],
                encoding: URLEncoding.queryString
            )
        default: .requestPlain
        }
    }

    /// KIS 는 엔드포인트마다 `tr_id` 가 다르다 — 이 분기를 TargetType 이 흡수하는 것이
    /// Moya 채택의 핵심 실익이다 (§10.4).
    var headers: [String: String]? {
        var base = ["content-type": "application/json; charset=utf-8"]
        switch self {
        case .issueToken: break
        case .domesticQuote: base["tr_id"] = "FHKST01010100"
        case .overseasQuote: base["tr_id"] = "HHDFS00000300"
        case .exchangeRate, .indexQuote: base["tr_id"] = "…"
        }
        return base
    }

    /// `sampleData` 는 TargetType 필수 멤버라 전체를 `#if DEBUG` 로 감쌀 수 없다.
    /// 릴리스에서는 빈 Data 를 반환해 CLAUDE.md 절대규칙 3(mock 은 릴리스 미포함)을 지킨다.
    var sampleData: Data {
        #if DEBUG
        KISSampleData.json(for: self)
        #else
        Data()
        #endif
    }
}
```

`appkey`/`appsecret` 을 `issueToken` 케이스의 associated value로 받는다 — `TargetType` 이 시크릿
저장소를 직접 읽지 않게 해서, 테스트에서 더미 키로 스텁이 가능하다.

### 9.5 Moya + Swift 6 strict concurrency

Moya 15의 공개 API는 **completion handler 기반**이고(`provider.request(_:completion:)`), async/await
API를 제공하지 않는다. 리액티브 확장(RxSwift·ReactiveSwift·Combine)만 있고 우리는 쓰지 않는다.
또한 `MoyaProvider`·`Moya.Response`는 `Sendable`이 아니다. 다음 3단 구조로 격리한다.

```swift
// Modules/Data/Sources/Remote/KIS/KISClient.swift
@preconcurrency import Moya

/// ① MoyaProvider 는 Sendable 이 아니다 → actor 안에 가둔다.
/// ② Moya.Response 를 actor 밖으로 내보내지 않는다 → 내부에서 Sendable DTO 로 디코딩.
/// ③ Moya 는 async API 가 없다 → continuation 브리지를 이 파일에만 둔다.
actor KISClient {
    private let provider: MoyaProvider<KISTarget>
    private let tokenStore: KISTokenStore

    init(provider: MoyaProvider<KISTarget>, tokenStore: KISTokenStore) {
        self.provider = provider
        self.tokenStore = tokenStore
    }

    func request<Payload: Decodable & Sendable>(
        _ target: KISTarget,
        as payload: Payload.Type
    ) async throws -> Payload {
        let response = try await send(target)
        guard (200..<300).contains(response.statusCode) else {
            throw AppError.server(statusCode: response.statusCode)
        }
        do {
            return try JSONDecoder.kis.decode(Payload.self, from: response.data)
        } catch {
            throw AppError.decoding(underlying: String(describing: error))
        }
    }

    /// Moya ↔ async/await 경계. 프로젝트 전체에서 이 함수 하나만 continuation 을 쓴다.
    private func send(_ target: KISTarget) async throws -> Moya.Response {
        try await withCheckedThrowingContinuation { continuation in
            provider.request(target) { result in
                switch result {
                case let .success(response):
                    continuation.resume(returning: response)
                case let .failure(error):
                    continuation.resume(throwing: AppError(moyaError: error))
                }
            }
        }
    }
}
```

`MoyaError` → `AppError` 매핑은 **`HannunData` 에 확장으로** 둔다. `AppError` 는 `HannunCore` 소속이고
Core는 Moya를 모르기 때문이다(§3 봉인 규칙 1).

```swift
// Modules/Data/Sources/Remote/AppError+Moya.swift
@preconcurrency import Moya

extension AppError {
    init(moyaError: MoyaError) {
        switch moyaError {
        case .underlying(let error as URLError, _) where error.code == .notConnectedToInternet:
            self = .offline                    // → 캐시 폴백 + StaleBadge (명세 §8)
        case .statusCode(let response):
            self = .server(statusCode: response.statusCode)
        case .objectMapping, .jsonMapping, .stringMapping, .imageMapping:
            self = .decoding(underlying: moyaError.localizedDescription)
        default:
            self = .network(underlying: moyaError.localizedDescription)
        }
    }
}
```

**주의:** `.offline` 이 `Loadable.failed` 로 가는 게 아니라 **캐시 폴백 경로**로 가야 한다.
명세 §8은 "네트워크 없음 시 마지막 성공값 + 갱신 실패 배지"를 요구하므로, `QuoteCache` 히트가 있으면
에러를 삼키고 stale 데이터를 반환한다. 에러 전파는 캐시도 비어 있을 때만.

### 9.6 인증 플러그인

토큰 주입·갱신은 `PluginType` 으로 분리해 `KISClient` 가 인증을 모르게 한다.

```swift
struct KISAuthPlugin: PluginType {
    let tokenProvider: @Sendable () -> String?

    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        guard !(target is KISTarget && isTokenIssue(target)) else { return request }
        var request = request
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        }
        return request
    }
}
```

- `prepare` 는 동기 함수라 **여기서 토큰을 재발급할 수 없다.** 만료 감지 → 재발급 → 재시도는
  `KISClient.request` 안에서 `401` 응답을 잡아 처리한다(actor 격리 덕에 재발급 중복 호출 방지가 자연스럽다).
- Moya의 `requestClosure` 를 이용한 비동기 서명 방식도 있으나, completion 중첩이 늘어나므로 채택하지 않는다.
- `NetworkLoggerPlugin` 은 `#if DEBUG` 에서만 플러그인 배열에 넣는다.

### 9.7 KIS 시크릿 관리

- `appkey`/`appsecret` → xcconfig(gitignore) → Info.plist → 런타임 주입 → `KISTarget.issueToken` 인자
- 발급된 access token → **Keychain**(`KISTokenStore`). `UserDefaults` 금지
- 토큰 갱신 로직은 `HannunData/Remote/KIS` 안에 캡슐화. Domain·Feature는 인증의 존재를 모른다

## 10. 설계 판단 근거와 대안

### 10.1 왜 Feature별 Domain/Data 타깃을 만들지 않았나

`docs/claude/architecture.md` 는 Feature마다 Presentation/Domain/Data 3계층을 두는 구조를 기술한다.
이를 타깃으로 옮기면 12개 Feature 타깃 + 공유 모듈이 되는데, 이 앱에서는 다음 이유로 성립하지 않는다.

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

### 10.4 Moya 채택 범위

**채택 이유** — 외부 API 2개(KIS·업비트)의 성질이 다르고, KIS 쪽이 Moya의 강점과 정확히 맞물린다.

| Moya의 기능 | 이 프로젝트에서의 실익 |
|---|---|
| `TargetType` 열거 | KIS는 엔드포인트마다 `tr_id` 헤더가 다르고 파라미터 인코딩도 섞인다(§9.4). URLSession 직접 사용 시 이 분기가 클라이언트 코드에 흩어진다 |
| `sampleData` + `stubClosure` | `URLProtocol` mock 없이 DTO 디코딩·폴백 테스트 가능(§6.1). 명세 §9 "실제 API 호출 없이 계산 로직 검증" 요구를 그대로 충족 |
| `PluginType` | 토큰 주입·로깅을 요청 파이프라인에서 분리(§9.6) |
| 컴파일 타임 체크 | 엔드포인트 오타·파라미터 누락이 런타임이 아니라 빌드에서 잡힘 |

**받아들인 비용** — 정직하게 적어 둔다.

- 의존성 트리가 0 → 2개(Moya + Alamofire). 개인 앱에서 URLSession으로 충분하다는 반론은 성립하며,
  실제로 업비트 공개 API만 있다면 Moya는 과잉이었다. **KIS의 헤더·인증 복잡도가 근거**다.
- Moya 15는 async/await·Swift 6 Sendable을 지원하지 않아 actor + continuation 브리지가 필요하다(§9.5).
  이 어댑터 코드(약 40줄)가 Moya 도입의 실질 비용이다.
- `Moya.Task` ↔ `_Concurrency.Task` 이름 충돌(§9.4).

**대안(채택 안 함)** — URLSession + `Endpoint` 구조체 직접 작성. 의존성 0, Sendable 문제 없음, 대신
스터빙 인프라(`URLProtocol` 서브클래스)와 헤더 분기 처리를 직접 만들어야 한다. Moya 어댑터 40줄보다
많은 코드가 필요하다고 판단해 채택하지 않았다.

**교체 가능성 유지** — §3의 봉인 규칙 3가지를 지키면 Moya는 `HannunData` 내부 구현 디테일에 머문다.
나중에 URLSession으로 되돌리거나 다른 라이브러리로 옮길 때 수정 범위는 `Remote/` 폴더 + `AppError+Moya.swift`
뿐이고, Domain·Feature·테스트는 손대지 않는다.

### 10.5 설계 문서 §3·§7과의 용어 정합

설계 문서 §3은 계층을 `View → ViewModel → Service → SwiftData 모델` 로 적었고, CLAUDE.md는
`View → ViewModel → UseCase → Repository → DataSource` 로 적었다. 이 문서는 **CLAUDE.md 쪽을
채택**하고, 설계 문서의 "Service"는 그중 `MarketDataService`(외부 시세 조회)를 가리키는 것으로 해석해
DataSource 위치에 배치했다. 설계 문서 §3 문구를 CLAUDE.md 용어로 맞추는 편집을 권한다.

설계 문서 §7은 "`MarketDataService` 프로토콜로 추상화, 마지막 조회 결과를 로컬에 캐싱"만 규정하고
구현 수단은 열어 두었다. 이 문서에서 그 자리를 **Moya `TargetType` 2종 + actor 클라이언트 2종 +
`CompositeMarketDataService`** 로 구체화했다(§4.2). 설계 문서에 별도 수정은 필요 없다 — 프로토콜
경계가 그대로 유지되기 때문이다.

## 11. 미결 사항 (착수 전 확인 필요)

① **배포 타깃 충돌 — 결정 필요.**
설계 문서 §1 타겟은 "iOS 17 이상"인데, UI 스펙과 CLAUDE.md는 iOS 26 전용 API(Liquid Glass,
`tabViewBottomAccessory`, `ConcentricRectangle`)를 전제로 작성됐다. 이 문서는 **iOS 26.0** 으로
확정했다. 확정 시 설계 문서 §1의 "iOS 17 이상"을 수정해야 한다. 만약 iOS 17을 유지해야 한다면
UI 스펙 §2.4·§3.1을 전면 재작성해야 하므로, 먼저 이 항목을 확정한 뒤 착수하는 것이 안전하다.

② **bundle identifier prefix.** `com.jeong.hannun` 은 임의 placeholder다. Apple Developer 팀의
실제 organization identifier로 교체해야 하고, CloudKit 컨테이너 ID
(`iCloud.{bundleId}`)도 함께 확정된다.

③ **Tuist 툴체인 — 해결됨.** `mise.toml` 에 `tuist = "4.202.6"` 으로 고정하고 설치·실행 확인까지
완료했다(§7.1). 남은 것은 §5 manifest를 `tuist edit` 으로 **컴파일 검증**하는 일이다 — 4.202.6에서
`Tuist.swift` / `.target(name:)` / `PackageSettings` API 형태가 이 문서와 일치하는지 M0에서 확인한다.

④ **CloudKit 스키마 제약 반영.** §9.2 제약에 맞춰 설계 문서 §4 엔티티 표의 "필수/null" 표기를
"모델 기본값 + 계층 검증"으로 다시 적을 필요가 있다.

⑤ **Moya 버전·Swift 6 빌드 검증 (M0에서 확인).** 이 문서는 Moya 15.x를 전제로 작성했다. M0 스캐폴딩
단계에서 아래 3가지를 실제로 확인하고, 결과에 따라 §5.5·§9.5를 조정해야 한다.

| 확인 항목 | 실패 시 대응 |
|---|---|
| `.upToNextMajor(from: "15.0.0")` 이 해석하는 실제 버전과 iOS 26 / Xcode 최신 toolchain 호환성 | 버전 상한 조정 또는 fork 검토 |
| Moya·Alamofire가 `SWIFT_STRICT_CONCURRENCY=complete` + `warnings as errors` 상속 하에 빌드되는지 | §5.5의 `targetSettings` 로 두 패키지만 완화 |
| `@preconcurrency import Moya` 로 `MoyaProvider`·`Response` non-Sendable 경고가 실제로 억제되는지 | 억제 안 되면 클라이언트 actor에 `nonisolated(unsafe)` 저장 프로퍼티 또는 얇은 `@unchecked Sendable` 래퍼 도입 (범위를 `Remote/` 안으로 한정) |

세 항목 모두 **M0에서 빈 타깃만으로 검증 가능**하다 — Moya를 링크한 `HannunData` 에 `import Moya` 한
줄과 더미 `TargetType` 하나만 넣고 `tuist build` 하면 된다. 기능 구현 전에 반드시 통과시킬 것.

## 12. 착수 순서

| 단계 | 산출물 | 완료 기준 |
|---|---|---|
| M0 | Tuist 스캐폴딩 — §4 디렉터리, §5 manifest(Moya 포함), 빈 타깃 10개 | `tuist install && tuist generate && tuist build Hannun` 성공, `tuist graph` 가 §3과 일치, **§11-⑤ Moya 빌드 검증 3항목 통과** |
| M1 | `HannunCore` + `HannunDesignSystem` — 토큰(§2.1~2.3), Loadable/AppError/DIContainer, 공통 컴포넌트 18종 | 컴포넌트별 `#if DEBUG` 프리뷰가 Feature 없이 렌더 |
| M2 | `HannunDomain` 엔티티·프로토콜 + `HannunData` Persistence | 인메모리 컨테이너로 CRUD 통과, CloudKit 스키마 검증 통과 |
| M3 | `HannunData` Remote — `KISTarget`/`UpbitTarget`, actor 클라이언트, `KISAuthPlugin`, 캐시 | `HannunDataTests` 통과(스터빙 기반, §6.1), 오프라인 시 마지막 성공값 폴백 동작, 401 → 토큰 재발급 → 재시도 확인 |
| M4 | `PortfolioFeature` (`PF-1`~`PF-6`) | 종목 CRUD·입출금 CRUD 실기기 확인. **다른 탭의 데이터 원천이므로 첫 Feature** |
| M5 | `NetWorthFeature` (`NW-1`~`NW-4`) | 총자산·도넛·통화 토글, `NW-4` 탭 간 이동(AppRoute) 동작 |
| M6 | `PerformanceFeature` (`PM-1`~`PM-4`) | YTD·추이·벤치마크. `HannunDomainTests` YTD 케이스 통과 |
| M7 | `JournalFeature` (`JR-1`~`JR-4`) | 일지 CRUD·종목 태그·필터 |

M4를 Portfolio부터 시작하는 이유: `Holding` 입력이 없으면 나머지 3개 탭이 전부 빈 상태만 보여주므로
수동 검증이 불가능하다.
