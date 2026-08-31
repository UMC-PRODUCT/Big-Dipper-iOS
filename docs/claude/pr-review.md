# PR 리뷰 규칙

> PR 리뷰 핵심 원칙, 작성 형식, 체크리스트 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

- 작성자: 제옹(euijjang97)

## 리뷰 핵심 원칙

1. **서버 응답 숫자는 전 레이어 String 통일**
   - 서버가 모든 정수를 String으로 직렬화 → Response DTO뿐 아니라 **Domain Model, Repository Protocol 파라미터까지 `String`**
   - Int 변환은 연산이 필요한 시점에만 수행
   - DTO에서 `decode(Int.self)` 직접 호출 금지 → `decodeIntFlexibleIfPresent` 사용
   - Request DTO (우리가 보내는 쪽)는 Int 허용

2. **Response DTO는 Synthesized Codable 금지**
   - 반드시 custom `init(from:)` + `encode(to:)` 작성
   - Int 필드가 없더라도 패턴 통일을 위해 custom init 권장

3. **모듈 간 접근 제어자**
   - Domain Model의 프로퍼티/이니셜라이저에 `public` 필수
   - 다른 모듈(Data, Presentation)에서 접근 시 컴파일 에러 방지

4. **Mock 데이터는 `#if DEBUG` 가드**
   - 릴리스 빌드에 포함되지 않도록 감싸기

5. **파일 배치 일관성**
   - Color 확장 등 시각적 매핑의 배치 위치(CoreDesignSystem vs CoreUIComponents)를 팀 내 통일

6. **머지 충돌 사전 감지**
   - 동일 파일을 여러 PR이 수정할 경우 머지 순서 조율 필요 명시

## 리뷰 작성 형식

PR 리뷰는 **지적 사항이 있는 파일만** 아래 형식으로 작성한다. 이상 없는 파일은 생략.

```
## PR #{번호} — {제목} ({작성자})

### {파일 경로}
* {파일 설명 한 줄}

> {지적 사항 / 개선 제안}

---

### {파일 경로}
* {파일 설명 한 줄}

> {지적 사항 / 개선 제안}
```

## 리뷰 시 체크리스트

- [ ] 서버 응답 기반 숫자 필드가 `String`으로 선언되어 있는가
- [ ] Response DTO에 custom `init(from:)` 이 정의되어 있는가
- [ ] Domain Model에 `public init` / `public let`이 있는가
- [ ] Mock 데이터가 `#if DEBUG`로 감싸져 있는가
- [ ] 동일 파일 수정하는 다른 PR과의 충돌 가능성 확인
- [ ] 타입 불일치 없는가 (같은 필드가 한 곳은 Int, 다른 곳은 String 등)
- [ ] Network Router에 인라인 딕셔너리 없이 DTO로 분리되어 있는가
- [ ] 테스트 코드가 포함된 PR은 테스트 품질도 함께 리뷰
- [ ] **식별자에 의미 없는 숫자 접미사가 없는가** (`text1`, `value2`, `btn3Color` 등) — `docs/claude/coding-style.md` 참고
- [ ] 약어가 도메인 표준(`id`, `URL`, `API` 등)을 제외하고 풀어 써졌는가
- [ ] 같은 종류 데이터를 `xxx1`/`xxx2`로 펼치지 않고 컬렉션/enum으로 묶었는가

## 테스트 코드 리뷰 기준

PR에 테스트 파일이 포함되어 있으면 반드시 아래 항목을 함께 리뷰한다.

1. **Swift Testing 프레임워크 사용**: `XCTest` 대신 `import Testing` + `@Suite` / `@Test` / `#expect` 사용
2. **네이밍**: `@Suite` 설명은 "대상 — 검증 범주 (도메인 규칙)" 형식, `@Test` 설명은 한글로 입력-결과를 명시
3. **파라미터화 테스트**: 동일 로직의 여러 입력은 `arguments:` 로 묶어 중복 제거
4. **경계값 테스트**: 경계 조건(0, nil, 빈 문자열, 동일 시간 등)에 대한 테스트 존재 여부
5. **Helper/Fixture 분리**: 테스트 전용 helper (`makeSession()`, `makeAttendance()` 등)가 `private`으로 격리되어 있는가
6. **`@MainActor` 테스트**: `@Observable` / `@MainActor` 모델 테스트 시 Suite/Test에 `@MainActor` 어노테이션이 있는가
7. **`.disabled` 사용**: Secret/인프라 미구축으로 실행 불가한 테스트는 `.disabled("사유")` 로 명시했는가
8. **테스트 커버리지**: 핵심 도메인 로직(상태 전이, 매핑, computed property)에 대한 테스트가 누락되지 않았는가
9. **파일명 컨벤션**: `{대상}Tests.swift` (복수형 Tests)
