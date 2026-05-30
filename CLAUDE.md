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
- **현재 버전**: 1.7.0
- **두 빌드 축**: `AppProduct/`(레거시 xcodeproj) + `UMCApp/`(Tuist) — **신규 작업은 `UMCApp/` 기본**

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
   정수 필드는 `decode(Int.self)` 직접 호출 금지 → `decodeFlexibleIntIfPresent` 헬퍼 사용.
   (Request/Encodable DTO는 제외 — Int 그대로 OK)
4. **모듈 간 노출 타입은 `public`** — Domain Model의 프로퍼티/이니셜라이저에 `public` 필수.
5. **Mock 데이터는 `#if DEBUG` 가드** — 릴리스 빌드 미포함.
6. **Network Router에 인라인 딕셔너리 금지** — 파라미터는 Query/Body DTO로 캡슐화.
7. **식별자에 의미 없는 숫자 접미사 금지** — `text1`/`btn2Color` 등 금지, 역할이 드러나는 이름 부여.
8. **커밋 메시지에 `Co-Authored-By` 라인 절대 추가 금지.**

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
# AppProduct (xcodeproj)
open AppProduct/AppProduct.xcodeproj

# UMCApp (Tuist) — 표준 진입점은 Makefile
cd UMCApp && make open      # generate + Xcode 열기
cd UMCApp && make test      # 테스트
cd UMCApp && make doctor    # 환경 진단
```

- Tuist 버전은 `UMCApp/mise.toml`(`4.155.0`)로 고정 · Deployment Target iOS 26.3
- 상세: `docs/claude/build-and-modules.md`, `UMCApp/MAKEFILE_GUIDE.md`

## 상세 레퍼런스 (필요 시 Read)

프로젝트 규약 — 해당 작업을 할 때 먼저 열어본다:

| 주제 | 문서 | 언제 읽나 |
|------|------|----------|
| 빌드 & Tuist 모듈 구조 | `docs/claude/build-and-modules.md` | 모듈 추가, 빌드 설정, 의존성 |
| 아키텍처 / Observation / 에러 | `docs/claude/architecture.md` | ViewModel·UseCase·에러 처리 작업 |
| Network Router (Moya) | `docs/claude/network-router.md` | API 엔드포인트/DTO 추가 |
| Response DTO 디코딩 | `docs/claude/response-dto-decoding.md` | Response DTO 작성/수정 |
| 디자인 시스템 & 성능 | `docs/claude/design-system.md` | UI/토큰/Glass/렌더링 최적화 |
| 코딩 스타일 & 네이밍 | `docs/claude/coding-style.md` | 네이밍 판단이 필요할 때 |
| Git Workflow | `docs/claude/git-workflow.md` | 브랜치/커밋/PR/배포 |
| 프로젝트 구조(AppProduct) | `docs/claude/project-structure.md` | 레거시 디렉터리 탐색 |
| PR 리뷰 규칙 & 체크리스트 | `docs/claude/pr-review.md` | PR 리뷰 작성 시 |

iOS 26 프레임워크 API — 신규 Apple API를 다룰 때:

| 모음 | 인덱스 | 언제 읽나 |
|------|--------|----------|
| iOS 26 프레임워크 가이드(20종) | `docs/claude/ios26-frameworks/INDEX.md` | Liquid Glass, FoundationModels, SwiftData 상속, 신규 SwiftUI/Concurrency API 등 |
