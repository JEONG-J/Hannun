# 변경 이력

한눈(Hannun)의 릴리즈 기록. 최신 버전이 위에 온다.

버전은 [유의적 버전](https://semver.org/lang/ko/)을 따르고,
`MARKETING_VERSION`(`App/Config/Hannun.shared.xcconfig`)과 `v` 접두 태그가 같은 값을 가리킨다.
빌드 번호(`CURRENT_PROJECT_VERSION`)는 Xcode Cloud 가 빌드마다 덮어쓰므로 여기 적지 않는다.

## [1.1.0] — 2026-08-10

### 추가

- 앱 아이콘을 얹은 정적 런치 화면. 배경이 첫 화면(`backgroundPrimary`)과 같은 값이라
  런치 화면에서 탭 화면으로 넘어갈 때 색이 튀지 않는다.

### 수정

- 기록이 없는 성과 탭에서 카드 두 장이 스피너만 돌다 사라지던 구간을 없앴다.

### 변경

- 지원 기기를 아이폰으로 좁혔다.
- 쓰지 않는 백그라운드 모드를 지우고, 앱스토어 재제출용 스크린샷 시안을 넣었다.
- 배포 브랜치 규칙 문서를 실제 Xcode Cloud 시작 조건에 맞췄다.

## [1.0.0] — 2026-08-09

첫 앱스토어 릴리즈.

현금·국내/해외 주식·ETF·코인을 한 곳에서 추적하는 개인 자산관리 앱.
순자산 · 포트폴리오 · 투자 성과 · 매매일지 네 개 탭으로 구성했다.

[1.1.0]: https://github.com/JEONG-J/Hannun/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/JEONG-J/Hannun/releases/tag/v1.0.0
