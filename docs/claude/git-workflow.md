# Git Workflow

> 브랜치 전략, 커밋/PR 규칙 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

Git Flow + **연속 브랜치 파생** 지원

## 브랜치 전략

- **통합 브랜치는 `main`** — 이 저장소에는 `develop` 이 없다. feature 브랜치는 `main` 에서 분기해 `main` 으로 PR 한다.
- **연속 브랜치**: feature에서 다음 feature 파생 가능 (티켓 단위 분리)
- **PR 대기 중 작업**: 승인 대기 중 이전 브랜치에서 다음 브랜치 생성 가능
- **동기화**: main에서 merge 대신 `fetch + rebase` 사용

## 배포 브랜치 전략

- **TestFlight 배포**: `main` 에서 `testFlight/{버전}` 브랜치를 따서 그대로 푸시
- **Release 배포**: `main` 에서 `release/{버전}` 브랜치를 따서 그대로 푸시
- 버전은 `MARKETING_VERSION` 을 그대로 쓴다 (`release/1.0.0`)
- **푸시 자체가 Xcode Cloud 빌드를 트리거한다** — PR·머지 대상 브랜치가 따로 없다 (아래 참고)
- 배포 브랜치에 직접 커밋하지 않는다. 고칠 게 있으면 `main` 에서 고치고 브랜치를 다시 딴다

> `testFlight` / `release` 라는 **장수 브랜치를 두지 않는다.** git 은 `refs/heads/release` 와
> `refs/heads/release/1.0.0` 을 동시에 가질 수 없어서(파일 vs 디렉터리 충돌) 둘은 공존이 불가능하다.
> 버전별 브랜치가 남는 쪽이 어느 커밋이 나갔는지 추적하기도 낫다.

## 커밋 형식

`type: 작업 내용`

커밋 메시지는 제목 한 줄 + 빈 줄 + 변경사항 bullet list 형식으로 작성.

| Type | 용도 |
|------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 |
| `docs` | 문서 |
| `chore` | 기타 |
| `test` | 테스트 |
| `design` | UI/디자인 시스템 |

**커밋 메시지에 `Co-Authored-By` 라인을 절대 추가하지 마세요.**
"Generated with Claude Code" 등 AI가 작성했음을 드러내는 문구도 커밋 메시지에 넣지 않습니다.

## PR 규칙

- 최소 1인 Approve 필수
- main 직접 푸시 금지
- Squash and Merge 사용
- 배포 브랜치(`release/*` · `testFlight/*`)는 PR 대상이 아니다 — `main` 에서 따서 바로 푸시한다
- **PR 제목·본문에 AI 작성 흔적 금지** — `🤖 Generated with [Claude Code](...)` 푸터, `Co-Authored-By` 크레딧 등
  attribution 문구를 절대 넣지 않는다

## 이슈 생성 규칙

이슈는 제목 접두사 + 라벨 + 이슈 Type을 기본으로 채워서 생성한다.
이슈 제목·본문에도 "Generated with Claude Code" 등 **AI 작성 흔적(attribution) 문구를 절대 넣지 않는다.**

| 템플릿 | 제목 접두사 | 라벨 | 이슈 Type |
|--------|------------|------|-----------|
| 버그 수정 | `🐛 Bug: ` | `:bug: Bug` | `Bug` |
| 기능 추가 | `✨ Feature: ` | `:sparkles: Feature` | `Feature` |
| 디자인 반영 | `🎨 Design: ` | `:lipstick: UI` | `Task` |
| 리팩토링 | `♻️ Refactor: ` | `:hammer: Refactor` | `Task` |
| 문서 작업 | `📄 Docs: ` | `:page_facing_up: Docs` | `Task` |
| 기타 작업 | `🍀 ETC: ` | `:wrench: chore` | `Task` |

## 자동 배포 (Xcode Cloud)

**역할 분담** — 검증은 GitHub Actions, 배포는 Xcode Cloud.

| | GitHub Actions (`.github/workflows/ci.yml`) | Xcode Cloud |
|---|---|---|
| 트리거 | `main` 으로의 PR · `main` 푸시 | `testFlight/*` / `release/*` 브랜치 푸시 |
| 하는 일 | generate → inspect → build-all → test-all | Archive → 업로드 |

Xcode Cloud 워크플로에는 **Test 액션을 넣지 않는다.** 같은 테스트를 두 번 돌리면
무료 한도(월 25시간)만 태운다. 배포 브랜치로 올라가는 커밋은 이미 `main` 에서 Actions 검증을 거쳤다.

### ci_scripts/ci_post_clone.sh

이 저장소는 Tuist 프로젝트라 `.xcworkspace` / `.xcodeproj` 가 `.gitignore` 대상이다.
**클론 직후에는 Xcode 가 열 수 있는 프로젝트가 없으므로** 이 스크립트가 반드시 필요하다.
mise 설치 → `make bootstrap` → `make generate` 로 워크스페이스를 만든 뒤,
`CURRENT_PROJECT_VERSION` 을 `CI_BUILD_NUMBER` 로 덮어쓴다
(`Hannun.shared.xcconfig` 의 `1` 을 그대로 쓰면 두 번째 업로드부터 거부된다).

### App Store Connect 워크플로 (UI 설정 — 저장소에 없다)

| | TestFlight | Release |
|---|---|---|
| 시작 조건 | 브랜치 `testFlight/*` 변경 | 브랜치 `release/*` 변경 |
| 액션 | Archive · 스킴 `Hannun` · Configuration `Release` | 동일 |
| 배포 준비 | TestFlight (Internal Testing Only) | App Store Connect |
| 후처리 | 내부 테스터 그룹 배포 | **없음** — 심사 제출은 사람이 누른다 |
| 환경변수 | `KIS_APP_KEY` · `KIS_APP_SECRET` (Secret 체크) | 동일 |

`KIS_*` 를 비워 두어도 빌드는 통과한다 — 사용자가 앱 안에서 직접 키를 넣는 경로가 있다.

### 최초 1회 체크리스트

- [ ] App Store Connect 에 앱 레코드 생성 (`com.hannun.app`)
- [ ] 로컬에서 `make generate` → 워크스페이스를 Xcode 로 열고
      Product ▸ Xcode Cloud ▸ Create Workflow 로 GitHub 연동
      (온보딩 시점엔 로컬에 워크스페이스가 있어야 한다. Xcode Cloud 는 경로·스킴만 저장하고
      실제 빌드 때는 `ci_post_clone.sh` 가 생성한다)
- [ ] **CloudKit 스키마를 Production 으로 배포** — `HannunModelContainer.swift` 가
      SwiftData + CloudKit 동기화를 쓰는데 **TestFlight 빌드는 CloudKit Production 환경을 사용한다.**
      Development 에만 스키마가 있으면 앱은 뜨지만 데이터가 안 붙는다. 첫 배포의 최대 함정.
- [ ] 워크플로 환경의 Xcode 가 **iOS 26.4 SDK** 를 포함하는지 확인 (배포 타깃이 26.4)
- [ ] 첫 아카이브 후 `aps-environment` 확인 — `Hannun.entitlements` 는 `development` 로 두었다.
      Xcode 가 App Store 배포용 export 시 `production` 으로 바꿔 주므로 건드리지 않는다
      (여기서 `production` 으로 박으면 로컬 개발 빌드 서명이 깨진다). 업로드가 이 값으로 거부되면 그때 조정한다.
- [ ] 이미 같은 빌드 번호를 올린 적이 있으면 워크플로 설정에서 시작 빌드 번호를 올린다
