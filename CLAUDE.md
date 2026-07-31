# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **구조 안내**: 이 파일은 **핵심 요약 + 절대 규칙 + 레퍼런스 인덱스**만 담는 허브입니다.
> 주제별 상세 내용은 `docs/claude/` 로 분리되어 있으며, **필요할 때 해당 파일을 `Read` 로 열어** 참고합니다.
> (컨텍스트 절약을 위해 `@import` 로 전체를 인라인하지 않습니다.)

## Project Overview

**Hannun — iOS 26 (Liquid Glass) 프로젝트**

현금·국내/해외 주식·ETF·코인을 한 곳에서 추적하는 **개인 자산관리 앱**.
순자산 / 포트폴리오 / 투자 성과 / 매매일지 4개 탭으로 구성한다.
제품 요구사항 상세는 `docs/design/2026-07-21-personal-asset-management-ios-app-design.md` 참고.

## 아키텍처 한눈에

**Feature-Based Modular + Clean Architecture + Observation**

```
View ←→ ViewModel(@Observable) → UseCase(Protocol) → Repository → DataSource
                                    ↑  DIContainer가 Protocol 구현체 주입
```

- **Presentation → Domain → Data** 단방향. 상위는 하위의 Protocol에만 의존 (DIP)
- **Router**: AppRouter(모듈 간/딥링크) + Feature Router(내부 화면). Tab별 독립 `NavigationStack`
- 상세: `docs/claude/architecture.md`

## 절대 규칙 (항상 적용)

이 항목들은 위반 시 컴파일 에러·런타임 크래시·리뷰 반려로 이어지므로 **예외 없이 지킵니다.**

1. **상태 관리는 `@Observable` 매크로만** — `@StateObject`/`@ObservedObject`/`@Published` 금지.
   예외: 앱 생명주기 전역 관리자. View는 `@State private var viewModel` 패턴.
2. **모듈 간 노출 타입은 `public`** — Domain Model의 프로퍼티/이니셜라이저에 `public` 필수.
3. **Mock 데이터는 `#if DEBUG` 가드** — 릴리스 빌드 미포함.
4. **식별자에 의미 없는 숫자 접미사 금지** — `text1`/`btn2Color` 등 금지, 역할이 드러나는 이름 부여.
5. **커밋·PR·이슈에 AI 작성 흔적(attribution) 절대 금지** — 커밋 메시지의 `Co-Authored-By` 라인,
   PR·이슈 제목/본문의 `🤖 Generated with [Claude Code](...)` 푸터 등 AI가 작성했음을 드러내는 문구 일체 추가 금지.

## 코딩 스타일 (요약)

- 들여쓰기 4 spaces(탭 금지) · 줄 길이 최대 99자 · 외부 불필요 상태는 `private`
- View 내부 전용 상수는 `fileprivate enum Constants`
- 약어 금지(`id`/`URL`/`API` 등 도메인 표준만 허용) · 타입명을 이름에 박지 않기
- MARK: `// MARK: - Property` / `// MARK: - Body` / `// MARK: - Function`
- 상세 + 안티패턴 예시: `docs/claude/coding-style.md`

## 에러 처리 (요약)

- **Loadable** (`.idle/.loading/.loaded/.failed`): 화면 내 인라인 상태 (리스트 로딩, 도메인 에러, 검증 실패)
- **ErrorHandler**: 흐름 중단형 전역 Alert (세션 만료, 권한, 네트워크 오류)
- **AlertPrompt**: 확인/취소 다이얼로그 (파괴적 작업, 분기점) — `.alertPrompt(item:)`
- 상세: `docs/claude/architecture.md`

## 빌드 명령 (요약)

<!-- TODO: Hannun 빌드/실행 세팅 확정 후 작성 -->

## 상세 레퍼런스 (필요 시 Read)

제품 설계 — 무엇을 만드는지(요구사항/기능 명세) 확인할 때:

| 주제 | 문서 | 언제 읽나 |
|------|------|----------|
| 앱 설계 문서 (범위·데이터 모델·화면·기능 명세·외부 API) | `docs/design/2026-07-21-personal-asset-management-ios-app-design.md` | 기능 구현/이슈 작성 전 요구사항 확인, 기능 ID(NW-/PF-/PM-/JR-) 참조 |

프로젝트 규약 — 해당 작업을 할 때 먼저 열어본다:

| 주제 | 문서 | 언제 읽나 |
|------|------|----------|
| 아키텍처 / Observation / 에러 | `docs/claude/architecture.md` | ViewModel·UseCase·에러 처리 작업 |
| 코딩 스타일 & 네이밍 | `docs/claude/coding-style.md` | 네이밍 판단이 필요할 때 |
| 디자인 시스템 & 성능 | `docs/claude/design-system.md` | UI/Glass/렌더링 최적화 |
| Git Workflow | `docs/claude/git-workflow.md` | 브랜치/커밋/PR/이슈/배포 |
| PR 리뷰 규칙 & 체크리스트 | `docs/claude/pr-review.md` | PR 리뷰 작성 시 |

iOS 26 프레임워크 API — 신규 Apple API를 다룰 때:

| 모음 | 인덱스 | 언제 읽나 |
|------|--------|----------|
| iOS 26 프레임워크 가이드(20종) | `docs/claude/ios26-frameworks/INDEX.md` | Liquid Glass, FoundationModels, SwiftData 상속, 신규 SwiftUI/Concurrency API 등 |
