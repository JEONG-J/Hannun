# Git Workflow

> 브랜치 전략, 커밋/PR 규칙 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

Git Flow + **연속 브랜치 파생** 지원

## 브랜치 전략

- **연속 브랜치**: feature에서 다음 feature 파생 가능 (티켓 단위 분리)
- **PR 대기 중 작업**: 승인 대기 중 이전 브랜치에서 다음 브랜치 생성 가능
- **동기화**: develop에서 merge 대신 `fetch + rebase` 사용

## 배포 브랜치 전략

- **TestFlight 배포**: `testFlight/{번호}` 브랜치 생성 → `testFlight`으로 PR 머지
- **Release 배포**: `release/{번호}` 브랜치 생성 → `release`로 PR 머지
- 배포 브랜치는 `develop`에서 분기하여 번호를 순차적으로 매김
- 직접 푸시 금지, 반드시 PR을 통해 머지

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
- main/develop 직접 푸시 금지
- Squash and Merge 사용
- **배포 PR 예외**: `testFlight`, `release` 브랜치로의 PR은 **Merge Commit** 사용 (커밋 히스토리 동기화를 위해)
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
