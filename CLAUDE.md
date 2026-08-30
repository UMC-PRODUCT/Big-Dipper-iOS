# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **구조 안내**: 이 파일은 **핵심 요약 + 절대 규칙 + 레퍼런스 인덱스**만 담는 허브입니다.
> 주제별 상세 내용은 `docs/claude/` 로 분리되어 있으며, **필요할 때 해당 파일을 `Read` 로 열어** 참고합니다.
> (컨텍스트 절약을 위해 `@import` 로 전체를 인라인하지 않습니다.)

## Project Overview

**UMC(University MakeUs Challenge) 동아리 운영 관리 앱** — SwiftUI + iOS 26.2+ (Liquid Glass)

- **App Statement**: "Focus on Growth, We Handle the Ops"
- **목적**: 동아리 운영 도구 일원화 (디스코드/구글시트/노션 분산 문제 해결)
- **주요 모듈**: 인증/온보딩, 홈 대시보드, 공지사항, 운영/학교 관리, 스터디/활동, 커뮤니티, 마이페이지
- **Killer Features**: The Ping (공지 수신 확인), Mobile-First Admin, GPS 기반 스마트 출석
- **현재 버전**: 2.2.0 (최신 릴리즈 태그 `v2.2.0`)
- **두 빌드 축**: `AppProduct/`(레거시 xcodeproj, **`v2.2.0`에 동결 — 수정 금지**) + `UMCApp/`(Tuist) — **모든 신규·유지보수·이식 작업은 `UMCApp/`에서만 수행** (절대 규칙 #9 참조)

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
   예외: 앱 생명주기 전역 관리자(`AppFlowViewModel`). View는 `@State private var viewModel` 패턴.
2. **서버 응답 정수는 전 레이어 `String` 통일** — 서버가 모든 정수를 String으로 직렬화한다.
   Response DTO·Domain Model·Repository Protocol 파라미터까지 `String`. Int 변환은 연산 시점에만.
3. **Response DTO는 synthesized Codable 금지** — custom `init(from:)` + `encode(to:)` 필수.
   정수 필드는 `decode(Int.self)` 직접 호출 금지 → `decodeIntFlexibleIfPresent` 헬퍼 사용.
   (Request/Encodable DTO는 제외 — Int 그대로 OK)
4. **모듈 간 노출 타입은 `public`** — Domain Model의 프로퍼티/이니셜라이저에 `public` 필수.
5. **Mock 데이터는 `#if DEBUG` 가드** — 릴리스 빌드 미포함.
6. **Network Router에 인라인 딕셔너리 금지** — 파라미터는 Query/Body DTO로 캡슐화.
7. **식별자에 의미 없는 숫자 접미사 금지** — `text1`/`btn2Color` 등 금지, 역할이 드러나는 이름 부여.
8. **커밋·PR·이슈에 AI 작성 흔적(attribution) 절대 금지** — 커밋 메시지의 `Co-Authored-By` 라인,
   PR·이슈 제목/본문의 `🤖 Generated with [Claude Code](...)` 푸터 등 AI가 작성했음을 드러내는 문구 일체 추가 금지.
9. **`AppProduct/`(레거시)는 `v2.2.0` 릴리즈 상태로 동결 — 절대 수정 금지.**
   PR 피드백 반영·버그 수정·리팩터·이식·마이그레이션 등 **어떤 작업에서도 `AppProduct/` 하위 파일을 절대 건드리지 않는다.** 모든 작업은 `UMCApp/`(Tuist)에서만 수행한다.
   - 위 절대 규칙·코딩 규약(특히 #2 서버 정수 `String` 통일 등)은 **`UMCApp/`(활성 코드베이스)에만** 적용된다. AppProduct는 동결 상태이므로 이런 규칙을 소급 적용하려고 손대서도 안 된다.
   - 실수로 `AppProduct/`가 변경되면 즉시 `git restore --source=v2.2.0 -- AppProduct/<경로>` 로 릴리즈 상태로 되돌린다.
   - 유일한 예외: 메인테이너가 **명시적으로 AppProduct 수정을 지시한 경우에만** 진행. 그 외에는 예외 없음.

10. **작업 브랜치명은 `{타입}/{이슈번호}` — 이슈를 먼저 만들고 그 번호를 쓴다.**
    타입은 이슈 템플릿과 1:1로 맞춘다: `feat` · `bug` · `design` · `refac` · `docs` · `chore`.
    (예: `docs/1203`, `feat/1195`) 설명형 브랜치명(`docs/repo-rename-links` 등) 금지.
    - 대응 이슈가 없으면 **브랜치를 만들기 전에 이슈부터 생성**한다 (제목 접두사·라벨·Type·Priority/Effort까지 채워서 — 상세: `docs/claude/git-workflow.md`).
    - **PR 제목은 `{이모지} [Type] {작업 내용} (#이슈번호)`** — 분류는 반드시 `[대괄호]`, 끝에 이슈번호.
      (예: `✨ [Feat] 명함 도메인 계층 — MyCard · 명함첩 · 교환 세션 UseCase (#1194)`)
      **이슈 제목 형식(`📄 Docs: …` — 콜론)을 PR 제목에 쓰지 않는다.** `[Docs]:`처럼 대괄호 뒤 콜론도 금지.
      (이모지·Type 매핑표: `docs/claude/git-workflow.md`)
    - **PR 생성 시 Assignee 와 라벨을 반드시 지정한다** — `gh pr create` 에 `--assignee "@me"` 와
      `[Type]` 대응 라벨(`--label ":page_facing_up: Docs"` 등)을 같이 넘긴다. 나중에 붙이지 않는다.
      (라벨명은 `gh label list` 출력과 정확히 일치해야 하며, 누락 시 `gh pr edit <번호> --add-assignee --add-label` 로 보정)
    - **PR 본문은 `.github/pull_request_template.md` 섹션 구조를 그대로 따른다.**
      임의 목차(`## 무엇을`·`## 검증` 등) 금지. `Closes #이슈번호`는 `## 🔗 관련 이슈` 섹션에 넣는다.
      ⚠️ `gh pr create --body "..."`는 템플릿을 불러오지 않는다 — 템플릿을 복사해 채운 뒤
      `--body-file`로 넘길 것. (섹션 표·예시: `docs/claude/git-workflow.md` "PR 본문 형식")
    - 이미 푸시한 브랜치명을 고쳐야 하면 GitHub 브랜치 rename API는 **열려 있던 PR을 닫아버리므로**, rename 후 새 PR을 만들고 닫힌 PR에 후속 PR 번호를 코멘트로 남긴다.
    - 배포 브랜치는 예외: `testFlight/{번호}` · `release/{번호}` (순차 번호, 이슈번호 아님).

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

```bash
# AppProduct (xcodeproj) — v2.2.0 동결. 열람/참고 전용, 수정 금지 (절대 규칙 #9)
open AppProduct/AppProduct.xcodeproj

# UMCApp (Tuist) — 표준 진입점은 Makefile. 모든 작업은 여기서.
cd UMCApp && make open      # generate + Xcode 열기
cd UMCApp && make test      # 테스트
cd UMCApp && make doctor    # 환경 진단
```

- Tuist 버전은 `UMCApp/mise.toml`(`4.155.0`)로 고정 · Deployment Target iOS 26.4
- 상세: `docs/claude/build-and-modules.md`, `UMCApp/MAKEFILE_GUIDE.md`

## 상세 레퍼런스 (필요 시 Read)

프로젝트 규약 — 해당 작업을 할 때 먼저 열어본다:

| 주제 | 문서 | 언제 읽나 |
|------|------|----------|
| 빌드 & Tuist 모듈 구조 | `docs/claude/build-and-modules.md` | 모듈 추가, 빌드 설정, 의존성 |
| Tuist 파일별 이관 매핑 | `docs/claude/tuist-file-mapping.md` | 레거시 파일을 어느 모듈/레이어로 옮길지 확인할 때 (필수 참조) |
| 아키텍처 / Observation / 에러 | `docs/claude/architecture.md` | ViewModel·UseCase·에러 처리 작업 |
| Network Router (Moya) | `docs/claude/network-router.md` | API 엔드포인트/DTO 추가 |
| Response DTO 디코딩 | `docs/claude/response-dto-decoding.md` | Response DTO 작성/수정 |
| 디자인 시스템 & 성능 | `docs/claude/design-system.md` | UI/토큰/Glass/렌더링 최적화 |
| watchOS 디자인 시스템 | `docs/claude/watch-design-system.md` | 워치 화면·컴포넌트 작업, Glass 절제 규칙 확인 |
| 코딩 스타일 & 네이밍 | `docs/claude/coding-style.md` | 네이밍 판단이 필요할 때 |
| Git Workflow | `docs/claude/git-workflow.md` | 브랜치/커밋/PR/이슈(템플릿·Type·Priority)/배포 |
| 프로젝트 구조(AppProduct) | `docs/claude/project-structure.md` | 레거시 디렉터리 탐색 |
| PR 리뷰 규칙 & 체크리스트 | `docs/claude/pr-review.md` | PR 리뷰 작성 시 |
| 3D 명함 Phase 0 검증 결과 | `docs/claude/business-card-3d-spike.md` | 3D 명함(#1246~#1249) 착수 전, 스파이크 실측치 확인 |
| 3D 명함 베이스 템플릿 · 앵커 규약 | `docs/claude/business-card-3d-anchor-contract.md` | #1247·#1248 구현 시, `BusinessCardTemplate` 앵커·머티리얼 슬롯 참조 및 계약 테스트 확인 |
| 근거리 교환 실기기 검증 | `docs/claude/nearby-exchange-device-verification.md` | 근거리 명함 교환을 실기기 2대로 검증할 때, 조직 팀 App ID capability·서명 문제를 풀 때 |

Apple 프레임워크 API — 신규 Apple API를 다룰 때:

| 모음 | 인덱스 | 언제 읽나 |
|------|--------|----------|
| Apple 프레임워크 가이드(20종) | `docs/claude/apple-frameworks/INDEX.md` | `glassEffect`·`GlassEffectContainer`(Liquid Glass) · 툴바 신규 API · `AttributedString`/리치 텍스트 · FoundationModels(온디바이스 LLM) · SwiftData 상속 · `@MainActor`/actor/async 동시성 · Swift Charts 3D · WebKit·AlarmKit·MapKit·StoreKit 연동 |
| Apple 스킬팩(9종 · reference 66종, Apple 원문) | `docs/claude/apple-frameworks/INDEX.md` §3 | **SwiftUI·App Intents 코드를 새로 쓰거나 리뷰할 때.** `@Observable`/`@State`/`@Binding` 소유권 · `@Environment`/`@Entry` 무효화 경고 · `ForEach`/`List` identity(`id: \.self` 안티패턴) · soft-deprecated API 확인(`NavigationView`, 구 `onChange`) · 조건부 `.if` 모디파이어 · 뷰 분해/init 비용 · `Animatable` · App Intents 스키마/`AppEnum` · UIKit 현대화 · Xcode 보안 빌드 설정 |

기획·설계 문서 — **별도 레포로 분리되어 있다**:

| 대상 | 위치 | 언제 참고하나 |
|------|------|--------------|
| 기획 문서 레포 | https://github.com/UMC-PRODUCT/Mobile_Planning_Repo (private) | 기능 설계 스펙·구현 계획·서버 전달용 명세를 읽거나 **새로 쓸 때** |

- 폴더: `server/`(서버팀 전달용 API·푸시 명세) · `specs/`(기능 설계 스펙, PRD) · `plans/`(구현 계획)
- 파일명: `{기능}_{제목}_{종류}.md` — 밑줄 3분할. (예: `푸시_푸시 딥링크_서버명세.md`)
  맨 앞 기능 이름으로 정렬되므로 같은 기능의 문서가 한자리에 모인다.
  종류는 `설계` · `PRD` · `구현계획` · `설계리뷰` · `서버명세` · `서버갭`.
  **작성일은 파일명에 넣지 않는다** — 문서 본문 상단 `작성일:` 줄에 적는다.
  고유명사·API 이름(`macOS`, `Command API`, `NavigationTitle`)은 원문 표기를 유지한다.
- **새 기획·설계 문서는 이 레포에 쓴다** — 코드 레포(`docs/`)에 만들지 않는다.
  과거 `docs/superpowers/` 는 `.gitignore` 에 걸려 있어 문서가 버전 관리 밖에 방치됐고,
  그래서 문서 축을 아예 분리했다. 그 ignore 규칙은 재발 방지용으로 남겨 둔다.
- 조회 수단: `gh api repos/UMC-PRODUCT/Mobile_Planning_Repo/contents/...` 또는 로컬 클론.
- 코드 레벨 규약(아키텍처·코딩 스타일·빌드)은 분리 대상이 아니다 — `docs/claude/` 에 그대로 있다.

백엔드(서버) — API 연동·서버 상태 확인이 필요할 때:

| 대상 | 위치 | 언제 참고하나 |
|------|------|--------------|
| Cygnus 서버 레포 | https://github.com/UMC-PRODUCT/cygnus-server/tree/main | API 엔드포인트·요청/응답 스펙 확인, 서버 구현/배포 상태 점검, iOS DTO와 실제 응답이 어긋날 때 원인 추적 |

- 조회 수단: `gh` CLI(`gh api repos/UMC-PRODUCT/cygnus-server/contents/...`, `gh search code --repo UMC-PRODUCT/cygnus-server ...`) 또는 `WebFetch`.
- **읽기 전용으로만 사용** — 서버 레포에 커밋·PR·이슈를 만들지 않는다(메인테이너가 명시적으로 지시한 경우 제외).
- 스펙 추측 금지: 필드명·타입·nullable 여부는 서버의 컨트롤러/DTO 실제 코드로 확인한 뒤 iOS Response DTO에 반영한다(절대 규칙 #2·#3과 함께 적용).
