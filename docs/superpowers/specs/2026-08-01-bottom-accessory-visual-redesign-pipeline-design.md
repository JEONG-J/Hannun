# BottomAccessory 비주얼 재제안 파이프라인 설계

- 날짜: 2026-08-01
- 상태: 승인됨
- 목표: 탭바 하단 액세서리(BottomAccessory)의 **비주얼 완성도**를 시안(hannun.pen)을 넘어 재제안하고,
  그 결과를 `docs/design/` 의 새 디자인 문서로 확정한다. 코드·시안(pen) 반영은 후속 작업.

## 배경

- 현재 구현은 iOS 26 `tabViewBottomAccessory` 시스템 캡슐 안에 내용물만 담는 구조
  (`Modules/DesignSystem/Sources/Components/BottomAccessory.swift`, UI 스펙 §3.1).
- 4개 탭이 서로 다른 내용을 등록한다: 순자산(시세 캡션 + 통화 토글), 포트폴리오(액션 버튼 2개),
  성과(벤치마크 칩 그룹), 매매일지(안내 캡션 + 작성 버튼).
- 사용자 판단: 시안 대비/구현 모두 비주얼 완성도가 아쉬움 → 시안 정렬이 아니라 **재제안**이 필요.

## 결정 사항

1. **새 디자이너 에이전트 신설** — `~/.claude/agents/haeun-designer.md`
   - 제안형 비주얼 디자이너. soyeon-ui-review(리뷰형)와 역할 구분.
   - 코드를 편집하지 않고 마크다운 제안서만 산출. 토큰에 없는 값은 "신규 토큰 제안"으로 명시.
   - tools: Read, Grep, Glob, Bash / model: opus.
2. **입력 패키지는 메인 세션이 준비**
   - hannun.pen 액세서리 노드 스크린샷 export (에이전트는 .pen 직접 접근 불가)
   - 현재 구현 소스 경로 목록, `ui-design-spec.md`, `docs/claude/design-system.md`
   - 불변 조건 명시: 시스템 캡슐이 배경을 그림(§3.1), glass-on-glass 금지, 44pt 터치 타깃,
     inline 축약 대응 유지.
3. **프로세스: 제안 → 교차리뷰**
   - haeun-designer 초안(expanded/inline × 4탭, 토큰 값 명시)
   - soyeon-ui-review 가 토큰 준수·접근성·Glass 규칙 관점 검증
   - 메인 세션이 종합, 충돌 지점은 사용자 확인 후 확정.
4. **산출 문서** — `docs/design/2026-08-01-bottom-accessory-visual-redesign.md`
   - 현황 진단 / 개선 원칙(3~5개) / 공통 규격(확정 토큰 값·신규 토큰 제안) /
     탭별 스펙(expanded·inline) / 접근성 / 후속 반영 계획(pen 역반영·§3.1 갱신·코드 구현).
5. **이번 범위 밖** — `ui-design-spec.md` §3.1 갱신, hannun.pen 수정, DesignSystem 코드 수정.

## 비고

- 이번 세션에서는 새 에이전트 파일이 Agent 도구의 타입 목록에 아직 등록되지 않았을 수 있어,
  동일 정의를 프롬프트로 넘긴 general-purpose 서브에이전트로 실행할 수 있다. 파일은 다음
  세션부터 정식 타입으로 쓰인다.
