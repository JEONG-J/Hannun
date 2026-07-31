# Swift 코딩 스타일 + 네이밍 규칙

> 코드 스타일, 식별자 네이밍 규칙 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

- **들여쓰기**: 4 spaces (탭 금지)
- **줄 길이**: 최대 99자
- **접근 제어자**: 외부 불필요 상태는 `private` 필수
- **상수**: View 내부 전용은 `fileprivate enum Constants`

## 파일 헤더

**모든 `.swift` 파일은 Xcode 기본 헤더 블록으로 시작합니다.** 소스·테스트·Tuist 매니페스트 전부 해당합니다.

```swift
//
//  DIContainer.swift
//  HannunCore
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation
```

| 줄 | 내용 | 비고 |
|---|---|---|
| 2번째 | 파일명 (확장자 포함) | 파일을 rename 하면 같이 고친다 |
| 3번째 | 파일이 속한 **타깃 이름** | `HannunCore`·`PortfolioFeature` 등. 폴더명이 아니다 |
| 5번째 | `Created by euijjang97 on M/D/YY.` | 생성자 고정, 날짜는 **만든 날** |

- 날짜 형식은 Xcode 그대로 **`M/D/YY`** — 한 자리 수에 0을 채우지 않는다 (`7/31/26`, `8/1/26`).
- **생성일은 이후 수정해도 갱신하지 않는다.** 변경 이력은 git 이 갖고 있다.
- 헤더 블록과 첫 `import` 사이에 빈 줄 하나.
- 매니페스트도 예외가 아니다. 타깃 줄에는 그 매니페스트가 정의하는 프로젝트 이름을 쓴다
  (루트 `Project.swift`·`Workspace.swift` → `Hannun`, `Modules/Core/Project.swift` → `HannunCore`,
  `Tuist/ProjectDescriptionHelpers/*.swift` → `ProjectDescriptionHelpers`).
- **헤더에 설계 문서 절 번호(`§11.0` 등)나 변경 이력을 쓰지 않는다.** 스펙 참조가 필요하면 해당
  타입·함수 위의 문서 주석(`///`)에 적는다. 헤더는 Xcode 가 만드는 형식 그대로 유지한다.

## 네이밍 규칙

식별자(상수·변수·프로퍼티·함수·case·타입)는 **무엇인지·왜 존재하는지**를 이름만으로 읽을 수 있어야 합니다.

### 원칙

1. **의미 없는 숫자 접미사 금지** — `text1`, `text2`, `value1`, `item2`, `section3` 처럼 카운터로 구분된 이름 사용 금지.
   같은 섹션 안의 여러 값이라도 각각 자기 역할을 드러내는 이름을 부여한다.
2. **연속 인덱스가 본질인 경우만 예외** — 1부터 N까지의 순서 자체가 의미인 경우 (예: `step1`, `step2`, `phase1`). 이외에는 모두 도메인 어휘로 이름 짓는다.
3. **컬렉션이면 컬렉션으로** — 여러 값이 *같은 종류의 데이터* 라면 `[Type]` 배열 또는 `enum` + 매핑을 쓰고, `xxx1`/`xxx2`로 펼치지 않는다.
4. **약어 금지(도메인 표준 제외)** — `usr`, `cnt`, `tmp` 대신 `user`, `count`, `temporary`. 단 `id`, `URL`, `API` 등 도메인 표준 약어는 허용.
5. **타입을 이름에 박지 않기** — `userArray`, `nameString` 대신 `users`, `name`. 단 의미 충돌이 있을 때만 한정사 부여 (예: `loginIdInput` vs `loginId`).

### ❌ 안티패턴

```swift
fileprivate enum Constants {
    static let supportText1: String = "이용 중 불편사항이 있으신가요?"
    static let supportText2: String = "고객센터 운영시간 09:00 - 18:00"

    static let title1: String = "로그인"
    static let title2: String = "회원가입"

    static let btn1Color: Color = .indigo500
    static let btn2Color: Color = .grey400
}
```

> 카운터만으로는 어떤 값이 어떤 역할인지 알 수 없다. 리뷰어가 본문(`Text(Constants.supportText2)`)을 봐도 무엇이 표시되는지 파악하려면 정의로 점프해야 한다.

### ✅ 권장 패턴

```swift
fileprivate enum Constants {
    static let supportInquiryPrompt: String = "이용 중 불편사항이 있으신가요?"
    static let supportOperatingHours: String = "고객센터 운영시간 09:00 - 18:00"

    static let loginScreenTitle: String = "로그인"
    static let signUpScreenTitle: String = "회원가입"

    static let primaryActionColor: Color = .indigo500
    static let disabledActionColor: Color = .grey400
}
```

> 호출부(`Text(Constants.supportInquiryPrompt)`)만 봐도 "지원 문의 안내 문구"가 표시된다는 것이 드러난다.

## MARK 구분

```swift
// MARK: - Property
// MARK: - Body
// MARK: - Function
```
