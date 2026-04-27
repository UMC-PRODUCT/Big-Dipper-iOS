# UMC PRODUCT TEAM iOS

> UMC Product Team이 제작하는 동아리 운영 관리 iOS 애플리케이션입니다.

[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)]()
[![Xcode](https://img.shields.io/badge/Xcode-26.2-blue.svg)]()
[![iOS](https://img.shields.io/badge/iOS-26.0+-blue.svg)]()
[![Architecture](https://img.shields.io/badge/Architecture-Feature+Modular+Clean-green.svg)]()

---

## 📌 문서 목적

이 README는 다음을 동시에 관리합니다.

- 공통 운영 정보(아키텍처, 개발 환경, 규칙)
- 기수별 정보(팀원, 기간, 신규 기능, 변경 사항)

기수가 늘어나도 아래 "기수 운영 보드"와 "기수별 상세"만 추가하면 누적 관리가 가능합니다.

## 📚 목차

- [기수 운영 보드](#-기수-운영-보드)
- [공통 정보](#-공통-정보)
- [기수별 상세](#-기수별-상세)
- [새 기수 추가 템플릿](#-새-기수-추가-템플릿)
- [참고 문서](#-참고-문서)

## 🗂️ 기수 운영 보드

| 기수 | 기간 | 상태 | 리드 | 상세 |
|------|------|------|------|------|
| 1기 | 2025.12.27 - 2026.02.20 | 완료 | 리버/이재원 | [1기 상세](#-1기-20251227---20260220) |
| 2기 | YYYY.MM.DD - YYYY.MM.DD | 예정 | 제옹/정의찬 | [2기 상세](#-2기-yyyyMMdd---yyyyMMdd) |
| N기 | YYYY.MM.DD - YYYY.MM.DD | 진행/예정 | TBD | 아래 템플릿으로 추가 |

## 🧩 공통 정보

### 소개

> **"Focus on Growth, We Handle the Ops"**

UMC(University MakeUs Challenge) 동아리 운영 관리 앱입니다.
디스코드, 구글 시트, 노션으로 분산된 운영 도구를 하나의 앱으로 통합하여 운영 효율성을 높이고, 부원들이 성장에 집중할 수 있는 환경을 제공합니다.

### 공통 기능 (기수 공통 유지 대상)

- 공지사항 수신 확인 (The Ping)
- Mobile-First Admin (출석/경고/공지 관리)
- GPS 기반 스마트 출석
- 커뮤니티 게시판

### 요구사항

- iOS 26.0+
- Xcode 26.2
- Swift 6.3

### 시크릿 / Firebase 설정 안내

- `Secrets.xcconfig`의 실제 키 값(`BASE_URL`, `KAKAO_KEY`)은 팀 내부 문서 기준으로 설정합니다.
- `GoogleService-Info.plist`는 내부 가이드에 따라 발급/배치합니다.
- 실제 키/설정 파일은 원격 저장소에 업로드하지 않습니다.

### 아키텍처

**Feature-based Modular + Clean Architecture + Observation**

```text
View <-> ViewModel(@Observable) -> UseCase(Protocol) -> Repository -> DataSource
                               ^
                 DIContainer가 Protocol 구현체 주입
```

| 계층 | 역할 | 의존 방향 |
|------|------|-----------|
| Presentation | View, ViewModel | -> Domain |
| Domain | UseCase, Model, Interface | <- Data(구현) |
| Data | Repository, Router, DTO | Domain Protocol 구현 |

### 프로젝트 구조

```text
AppProduct/AppProduct/
├── App/
├── Core/
│   ├── Alert/
│   ├── Common/
│   │   ├── DesignSystem/
│   │   ├── Error/
│   │   └── UIComponents/
│   ├── DIContainer/
│   ├── Manager/
│   ├── Navigation/
│   ├── NetworkAdapter/
│   └── Services/
└── Features/
    ├── Activity/
    ├── Auth/
    ├── Community/
    ├── Home/
    ├── MyPage/
    ├── Notice/
    ├── Splash/
    └── Tab/
```

### 테스트

```bash
xcodebuild -project AppProduct/AppProduct.xcodeproj \
  -scheme AppProduct \
  test
```

- 인증 연동 테스트에는 루트 `.test-config.json`이 필요합니다.
- 샘플은 `AppProduct/AppProductTests/AuhTest/EmailVerificationTests.swift`를 참고합니다.

### Git / PR 규칙

- `main`/`develop` 직접 푸시 금지, 기능 브랜치에서 PR
- 커밋 제목 형식: `type: 작업 내용`
- PR 본문 최소 항목: 작업 내용 / 변경 이유 / 리뷰 포인트 / 추후 작업
- UI 변경 시 스크린샷/영상 첨부
- 최소 1명 Approve 후 `Squash and Merge`

## 🚀 기수별 상세

### 🥇 1기 (2025.12.27 - 2026.02.20)

#### 팀 구성

| 리버/이재원 | 제옹/정의찬 | 마티/김미주 | 소피/이예지 |
|:------:|:------:|:------:|:------:|
| <img src="https://github.com/user-attachments/assets/a4ddee14-419e-41da-a89a-e2c2fb23a03f" width="300" height="250"> | <img src="https://github.com/user-attachments/assets/00ba6ec3-d252-4e93-b467-b0d0ba654fb4" width="300" height="250"> | <img src="https://github.com/user-attachments/assets/7842f405-80c3-4394-8978-617c020f47d5" width="300" height="250"> | <img src="https://github.com/user-attachments/assets/1749df32-f292-4613-916d-b88cf2390cd2" width="300" height="250"> |
| PL | iOS, PM | iOS | iOS |
| [리버](https://github.com/jwon0523) | [제옹](https://github.com/JEONG-J) | [마티](https://github.com/alwn8918) | [소피](https://github.com/LeeYeJi546) |

#### 1기 신규/강화 기능

- The Ping 공지 미확인자 추적 및 재알림 UX 고도화
- Mobile-First Admin 운영 플로우 정착
- GPS 기반 스마트 출석 흐름 통합
- 알림 히스토리 SwiftData 저장 및 CloudKit 폴백 구조 적용

#### 1기 비고

- 디자인 시스템에서 iOS 26 Liquid Glass 가이드라인 반영
- CoreML 기반 알림 분류 테스트 리소스 운영

### 🥈 2기 (YYYY.MM.DD - YYYY.MM.DD)

#### 팀 구성

| 제옹/정의찬 | 리버/이재원 | 소피/이예지 | 원/김동민 | 도도/김도연 |
|:------:|:------:|:------:|:------:|:------:|
| <img src="https://github.com/user-attachments/assets/00ba6ec3-d252-4e93-b467-b0d0ba654fb4" width="300" height="250"> | <img src="https://github.com/user-attachments/assets/a4ddee14-419e-41da-a89a-e2c2fb23a03f" width="300" height="250"> | <img src="https://github.com/user-attachments/assets/1749df32-f292-4613-916d-b88cf2390cd2" width="300" height="250"> | _사진 추후 추가_ | _사진 추후 추가_ |
| PL | iOS | iOS | iOS | iOS |
| [제옹](https://github.com/JEONG-J) | [리버](https://github.com/jwon0523) | [소피](https://github.com/LeeYeJi546) | _추후 추가_ | _추후 추가_ |

#### 2기 신규/강화 기능

- [신규] 기능 A
- [개선] 기능 B
- [실험] 기능 C

#### 2기 비고

- 운영/기술 의사결정 요약
- 다음 기수로 넘길 TODO

## 🧱 새 기수 추가 템플릿

아래 블록을 복사해서 `기수별 상세` 섹션 하단에 이어서 추가하세요.

```md
### 🥈 N기 (YYYY.MM.DD - YYYY.MM.DD)

#### 팀 구성

| 이름/실명 | 이름/실명 | 이름/실명 |
|:------:|:------:|:------:|
| 역할 | 역할 | 역할 |
| [GitHub](https://github.com/) | [GitHub](https://github.com/) | [GitHub](https://github.com/) |

#### N기 신규/강화 기능

- [신규] 기능 A
- [개선] 기능 B
- [실험] 기능 C

#### N기 비고

- 운영/기술 의사결정 요약
- 다음 기수로 넘길 TODO
```

그리고 "기수 운영 보드"에 해당 기수 행을 1줄 추가합니다.

## 📎 참고 문서

- `README.md`
- `CLAUDE.md`
- `.github/pull_request_template.md`
- `AppProduct/Documentation.docc/Resources/NETWORK_API_GUIDE.md`
- `AppProduct/Documentation.docc/Resources/SECRET_CIDCD_GUIDE.md`
- `AppProduct/Documentation.docc/Resources/NOTICE_CLASSIFIER_GUIDE.md`
- `AppProduct/Documentation.docc/Resources/SCHEDULE_CLASSIFIER_GUIDE.md`
- `AppProduct/Documentation.docc/Resources/NOTICE_EDITOR_ROLE_TARGET_GUIDE.md`
- `AppProduct/Documentation.docc/Resources/NOTICE_TAB_MENU_SCHEME.md`

## 🛠️ 트러블슈팅 메모

- `SwiftData CloudKit init failed` 로그는 CloudKit 실패 후 로컬 폴백 상황일 수 있습니다.
- 시뮬레이터에서는 APNS 토큰 미설정으로 FCM 토큰 발급이 제한될 수 있습니다.
- Preview에서 ModelContainer 오류가 발생하면 in-memory 컨테이너 주입 여부를 확인하세요.
