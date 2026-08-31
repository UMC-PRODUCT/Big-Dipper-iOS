<div align="center">

# UMC PRODUCT TEAM · iOS

**"Focus on Growth, We Handle the Ops"**

UMC(University MakeUs Challenge) 동아리 운영을 하나의 앱으로 통합하는 iOS 클라이언트

[![App Store](https://img.shields.io/badge/App%20Store-다운로드-0D96F6?logo=apple&logoColor=white)](https://apps.apple.com/kr/app/umc/id6759412446)
[![Release](https://img.shields.io/github/v/release/UMC-PRODUCT/Big-Dipper-iOS?label=release&color=blue)](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/releases)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)]()
[![Xcode](https://img.shields.io/badge/Xcode-26.2-1575F9.svg)]()
[![iOS](https://img.shields.io/badge/iOS-26.0+-black.svg)]()
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20Modular-2ea44f.svg)]()

</div>

---

## 📖 소개

디스코드·구글 시트·노션으로 흩어진 동아리 운영 도구를 **하나의 앱으로 통합**하여,
부원이 운영 잡무 대신 성장에 집중할 수 있는 환경을 제공합니다.

<div align="center">

<a href="https://apps.apple.com/kr/app/umc/id6759412446">
<img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/ko-kr?size=250x83" height="60" alt="App Store에서 다운로드">
</a>

**App Store 정식 출시** · iOS 26.0 이상
공지·출석·스터디·커뮤니티를 UMC 계정 하나로.

</div>

### 🧩 주요 기능

| 기능 | 설명 |
|------|------|
| 🔔 **The Ping** | 공지 수신 확인 추적 · 미확인자 재알림 · 푸시 딥링크 진입 |
| 📍 **GPS 스마트 출석** | 지오펜스 기반 정시·지각·이탈 자동 판정, 지도에서 세션 장소 지정 |
| 📱 **Mobile-First Admin** | 출석 세션 · 상벌점 · 리치 텍스트 공지 · 스터디 커리큘럼/제출 현황 관리 |
| 💬 **실시간 커뮤니티 스레드** | STOMP over WebSocket 채팅 — 답장 인용·@멘션·반응, 공유 딥링크(`umc://thread/{id}`) |
| 🧠 **온디바이스 AI** | FoundationModels 기반 대화 요약·액션 아이템 추출·스레드 자동 분류 |
| 🪪 **명함 근거리 교환** | MultipeerConnectivity + NearbyInteraction, QR·딥링크 폴백 |
| ⌚️ **watchOS 컴패니언** | 출석 · The Ping · 다음 세션 Complication |
| 🛡️ **원격 운영 안전장치** | RemoteConfig 점검 킬스위치 · 강제 업데이트 오버레이 |

## 🛠️ 기술 스택

<div align="center">
<img width="1696" height="1021" alt="Image" src="https://github.com/user-attachments/assets/d683ff7d-0d4f-419a-92c1-4bd81510e0b3" />
</div>

## 🏢 iOS 팀 조직도

| 기수 | 기간 | 상태 | 조직도 · 팀원 |
|:---:|:---:|:---:|:---:|
| 🥇 1기 | 2025.12.27 – 2026.02.20 | 종료 | [Wiki › Team](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Team) |
| 🥈 2기 | 2026.03.10 – 2026.08.22 | 종료 | [Wiki › Team](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Team) |

> 기수별 조직도 이미지와 팀원 구성(사진·역할·GitHub)은 [Wiki › Team](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Team)에 누적 관리합니다.
> 새 기수는 Wiki에 추가하고 위 표에 한 줄만 더합니다. 기수별 기능·운영 기록은 [Wiki › Release History](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Release-History)에서 확인하세요.

## 📚 개발 문서 (Wiki)

아키텍처·코딩 컨벤션·빌드 방법 등 상세 가이드는 모두 **[Wiki](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki)** 로 이관했습니다.

| 주제 | 문서 |
|------|------|
| 🏗️ 아키텍처 | [Architecture](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Architecture) |
| 📐 절대 규칙 & 코딩 컨벤션 | [Coding Conventions](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Coding-Conventions) |
| ⚠️ 에러 처리 | [Error Handling](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Error-Handling) |
| 🌐 네트워크 & DTO 디코딩 | [Networking](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Networking) |
| 🎨 디자인 시스템 | [Design System](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Design-System) |
| 🧱 모듈 구조 (Tuist) | [Module Structure](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Module-Structure) |
| ⚙️ 빌드 & 실행 | [Build & Run](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Build-and-Run) |
| 🔀 Git 워크플로우 | [Git Workflow](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Git-Workflow) |
| 🔒 보호 경로 (CODEOWNERS) | [Protected Paths](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Protected-Paths) |
| 🛰️ API 커버리지 (Stella) | [Stella](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Stella) |

> 신규 합류자는 [Wiki Home](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki) → **빌드 & 실행** 순서로 시작하세요.
>
> 일부 경로(`Core/Foundation`·`Core/DesignSystem`·`UMCApp/Tuist/` 등)는 PR에 **소유자 승인**이 필요합니다.
> 대상 경로와 이유는 [Protected Paths](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Protected-Paths)를 참고하세요.

## 🔑 시크릿 설정

- `Secrets.xcconfig`(`BASE_URL`, `KAKAO_KEY`)와 `GoogleService-Info.plist`는 **팀 내부 채널**에서 수령합니다.
- 실제 키·설정 파일은 원격 저장소에 커밋하지 않습니다.
- 상세 절차: [Build & Run › 시크릿 설정](https://github.com/UMC-PRODUCT/Big-Dipper-iOS/wiki/Build-and-Run)

---

<div align="center">

**Made with ❤️ by UMC Product Team · iOS**

</div>
