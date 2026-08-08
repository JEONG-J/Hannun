<div align="center">

# Hannun · 한눈

**"흩어진 자산을 한눈에"**

현금 · 국내/해외 주식 · ETF · 코인을 한 곳에서 추적하는 **개인 자산관리 iOS 앱**

[![Swift](https://img.shields.io/badge/Swift-6.3-F05138.svg?logo=swift&logoColor=white)]()
[![Xcode](https://img.shields.io/badge/Xcode-26-1575F9.svg?logo=xcode&logoColor=white)]()
[![iOS](https://img.shields.io/badge/iOS-26.4+-black.svg?logo=apple&logoColor=white)]()
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20Modular-2ea44f.svg)]()
[![CI](https://github.com/JEONG-J/Hannun/actions/workflows/ci.yml/badge.svg)](https://github.com/JEONG-J/Hannun/actions/workflows/ci.yml)

</div>

---

## 📖 소개

증권사 앱 · 거래소 앱 · 엑셀로 흩어진 자산 현황을 **하나의 앱으로 합칩니다.**
보유 수량과 평단가만 직접 넣으면 현재가·환율은 앱이 가져오고, 평가금액 · 수익률 · 자산 추이는
그때그때 계산합니다. 서버 없이 **SwiftData + CloudKit** 으로 아이폰과 아이패드가 같은 데이터를 봅니다.

**핵심 기능**

- 💰 **통화 하나로 합산** — 원화·달러 자산을 KRW/USD 토글 하나로 전환해 총자산을 한 숫자로 봅니다
- 📈 **입출금을 걷어낸 수익률** — 입금·출금을 따로 기록해 YTD 수익률에서 제외하니 순수 투자 성과만 남습니다
- 🏁 **벤치마크 비교** — 코스피 · S&P 500 · 나스닥 · 비트코인과 같은 기간·같은 %로 겹쳐 봅니다
- 🤖 **온디바이스 일지 초안** — Apple Intelligence 가 매매일지 초안을 **기기 안에서** 씁니다 (내용이 밖으로 나가지 않습니다)
- 🔑 **내 앱키로 동작** — 시세 앱키를 사용자가 직접 넣고, iCloud 키체인으로 기기 사이에 따라옵니다

## 🛠️ 기술 스택

<div align="center">

**언어 · UI**

<img src="https://img.shields.io/badge/Swift%206.3-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.3">
<img src="https://img.shields.io/badge/SwiftUI-0071E3?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
<img src="https://img.shields.io/badge/Liquid%20Glass-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Liquid Glass">
<img src="https://img.shields.io/badge/Swift%20Charts-FF9500?style=for-the-badge&logo=swift&logoColor=white" alt="Swift Charts">
<img src="https://img.shields.io/badge/Observation-8E8E93?style=for-the-badge&logo=swift&logoColor=white" alt="Observation">

**데이터 · 보안**

<img src="https://img.shields.io/badge/SwiftData-0A84FF?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftData">
<img src="https://img.shields.io/badge/CloudKit-3693F3?style=for-the-badge&logo=icloud&logoColor=white" alt="CloudKit">
<img src="https://img.shields.io/badge/Keychain-4A4A4A?style=for-the-badge&logo=apple&logoColor=white" alt="Keychain">
<img src="https://img.shields.io/badge/URLSession-1D6EF3?style=for-the-badge&logo=swift&logoColor=white" alt="URLSession">
<img src="https://img.shields.io/badge/Foundation%20Models-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Foundation Models">

**빌드 · 품질**

<img src="https://img.shields.io/badge/Tuist-6236FF?style=for-the-badge&logoColor=white" alt="Tuist">
<img src="https://img.shields.io/badge/mise-4B32C3?style=for-the-badge&logoColor=white" alt="mise">
<img src="https://img.shields.io/badge/Xcode%2026-1575F9?style=for-the-badge&logo=xcode&logoColor=white" alt="Xcode 26">
<img src="https://img.shields.io/badge/Swift%20Testing-30B0C7?style=for-the-badge&logo=swift&logoColor=white" alt="Swift Testing">
<img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions">

**외부 시세 API**

<img src="https://img.shields.io/badge/한국투자증권%20Open%20API-0046FF?style=for-the-badge&logoColor=white" alt="KIS Open API">
<img src="https://img.shields.io/badge/Upbit%20Open%20API-093687?style=for-the-badge&logo=bitcoin&logoColor=white" alt="Upbit Open API">

</div>

| 구분 | 선택 | 이유 |
|------|------|------|
| 상태 관리 | `@Observable` (Observation) | `ObservableObject` 대비 프로퍼티 단위 추적 — 무관한 뷰 갱신이 없다 |
| 영속성 | SwiftData + CloudKit | 서버 없이 기기 간 동기화. 개인 1인 앱이라 백엔드를 둘 이유가 없다 |
| 네트워크 | `URLSession` + `actor` 직접 구현 | 호출 API 가 GET 6~7개 + POST 1개뿐 — 서드파티 어댑터 비용이 실익을 넘는다 |
| 외부 의존성 | **없음** (`Tuist/Package.swift` 미존재) | `tuist install` 단계가 사라지고 Swift 6 strict concurrency 를 전 타깃에 그대로 건다 |
| 모듈화 | Tuist 다중 프로젝트 워크스페이스 | 모듈 경계 = 파일 경계. 새 모듈은 디렉터리에 `Project.swift` 만 두면 등록된다 |
| 테스트 | Swift Testing | 툴체인 내장이라 의존성 0. `@Test(arguments:)` 가 수익률·환산 케이스 표에 그대로 맞는다 |

## 📱 앱 사용법

설치 직후 무엇부터 하면 되는지, 네 탭을 각각 어떻게 쓰는지는 위키에 정리했습니다.

> 👉 **[사용 가이드 (App Guide)](https://github.com/JEONG-J/Hannun/wiki/App-Guide)** — 첫 실행 · 시세 앱키 등록 · 탭별 사용법 · 자주 겪는 상황

## 📚 개발 문서 (Wiki)

아키텍처 · 코딩 컨벤션 · 빌드 방법 등 상세 가이드는 모두 **[Wiki](https://github.com/JEONG-J/Hannun/wiki)** 에 있습니다.

| 주제 | 문서 |
|------|------|
| 📱 앱 사용법 | [App Guide](https://github.com/JEONG-J/Hannun/wiki/App-Guide) |
| 🏗️ 아키텍처 | [Architecture](https://github.com/JEONG-J/Hannun/wiki/Architecture) |
| 📐 절대 규칙 & 코딩 컨벤션 | [Coding Conventions](https://github.com/JEONG-J/Hannun/wiki/Coding-Conventions) |
| ⚠️ 에러 처리 | [Error Handling](https://github.com/JEONG-J/Hannun/wiki/Error-Handling) |
| 🌐 네트워크 & 시세 연동 | [Networking](https://github.com/JEONG-J/Hannun/wiki/Networking) |
| 🎨 디자인 시스템 | [Design System](https://github.com/JEONG-J/Hannun/wiki/Design-System) |
| 🧱 모듈 구조 (Tuist) | [Module Structure](https://github.com/JEONG-J/Hannun/wiki/Module-Structure) |
| ⚙️ 빌드 & 실행 | [Build & Run](https://github.com/JEONG-J/Hannun/wiki/Build-and-Run) |
| 🔀 Git 워크플로우 | [Git Workflow](https://github.com/JEONG-J/Hannun/wiki/Git-Workflow) |

> 처음 클론했다면 [Build & Run](https://github.com/JEONG-J/Hannun/wiki/Build-and-Run) → [Architecture](https://github.com/JEONG-J/Hannun/wiki/Architecture) 순서로 읽으세요.

## 🧱 프로젝트 구조

```
Hannun/
├── App/                  # 앱 셸 — 엔트리포인트 · RootTabView · AppRouter · DI 등록
├── Features/             # Presentation 만 — NetWorth · Portfolio · Performance · Journal · Settings
├── Modules/
│   ├── Core/             # 공유 커널 — Money · Loadable · AppError · DIContainer · AppRoute
│   ├── DesignSystem/     # 디자인 토큰 · Glass 헬퍼 · 공통 컴포넌트
│   ├── Domain/           # SwiftData 엔티티 · Repository 프로토콜 · UseCase
│   ├── Data/             # Repository 구현체 · KIS/Upbit 클라이언트 · 캐시 · 온디바이스 AI
│   └── TestSupport/      # 테스트 전용 fake · fixture
├── Tuist/                # 매니페스트 헬퍼 (ProjectSettings · 프로젝트 팩토리)
├── Workspace.swift       # Modules/* · Features/* 를 glob 으로 묶는다
└── Makefile              # 모듈 단위 빌드/테스트 래퍼
```

```
L4  Hannun (.app)  ──→ Feature 5종 · HannunData        ← 구현체를 아는 유일한 타깃
L3  *Feature       ──→ HannunDomain · DesignSystem · Core
L2  HannunData     ──→ HannunDomain · Core
L1  HannunCore     ──→ (없음)
```

자세한 의존성 규칙과 금지 간선은 [Module Structure](https://github.com/JEONG-J/Hannun/wiki/Module-Structure) 를 보세요.

## ⚙️ 빌드

```bash
make bootstrap     # 최초 1회 — mise 로 Tuist 4.202.6 설치
make secrets       # xcconfig 를 .example 에서 생성 (앱키는 비워 둬도 됩니다)
make generate      # Workspace/Project 생성 — 매니페스트를 고치거나 파일을 새로 만들면 필수
make open          # Xcode 로 열기

make build         # 앱 빌드
make test-all      # 전체 테스트
make inspect       # 암묵적 의존성 검사 — 커밋 전에 돌립니다
make help          # 전체 타깃 + 모듈 ↔ 스킴 매핑
```

> `.xcodeproj` / `.xcworkspace` 는 **Tuist 생성물이라 커밋하지 않습니다.** 직접 편집하면 다음
> `make generate` 에 덮어써집니다. 의존성 · 리소스 · 테스트 추가는 해당 모듈의 `Project.swift` 를 고칩니다.

## 🔑 시세 앱키

시세 앱키는 **앱 바이너리에 넣지 않고 사용자가 직접 넣습니다.** 앱 안의 설정(⚙️) → 앱키·앱시크릿 입력 →
저장 시 실제 발급 요청으로 검증한 뒤 **키체인(iCloud 동기화)** 에 보관합니다.

- 발급: [한국투자증권 KIS Developers](https://apiportal.koreainvestment.com) — 계좌 개설 후 무료 발급
- 키가 없어도 앱은 돌아갑니다 — 코인 시세(업비트, 인증 불필요)와 현재가 수동 입력은 그대로 동작합니다
- `App/Config/Hannun.{debug,release}.xcconfig` 는 `.gitignore` 대상이며 `.example` 템플릿만 커밋합니다

자세한 절차는 [App Guide › 시세 앱키 등록](https://github.com/JEONG-J/Hannun/wiki/App-Guide) 을 보세요.

---

<div align="center">

**Made with ❤️ · Hannun**

[Issues](https://github.com/JEONG-J/Hannun/issues) · [Pull Requests](https://github.com/JEONG-J/Hannun/pulls) · [Wiki](https://github.com/JEONG-J/Hannun/wiki)

</div>
