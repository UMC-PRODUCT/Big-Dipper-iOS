<div align="center">

# UMC PRODUCT TEAM · iOS

**"Focus on Growth, We Handle the Ops"**

UMC(University MakeUs Challenge) 동아리 운영을 하나의 앱으로 통합하는 iOS 클라이언트

[![Release](https://img.shields.io/github/v/release/UMC-PRODUCT/umc-product-iOS?label=release&color=blue)](https://github.com/UMC-PRODUCT/umc-product-iOS/releases)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)]()
[![Xcode](https://img.shields.io/badge/Xcode-26.2-1575F9.svg)]()
[![iOS](https://img.shields.io/badge/iOS-26.0+-black.svg)]()
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20Modular-2ea44f.svg)]()

</div>

---

## 📖 소개

디스코드·구글 시트·노션으로 흩어진 동아리 운영 도구를 **하나의 앱으로 통합**하여,
부원이 운영 잡무 대신 성장에 집중할 수 있는 환경을 제공합니다.

**Killer Features**

- 🔔 **The Ping** — 공지 수신 확인 추적 및 미확인자 재알림
- 📱 **Mobile-First Admin** — 출석·경고·공지 운영을 모바일에서 처리
- 📍 **GPS 스마트 출석** — 위치 기반 자동 출석

## 🛠️ 기술 스택

| 구분 | 사용 기술 |
|------|-----------|
| 언어 | Swift 6.3 |
| UI | SwiftUI · iOS 26 Liquid Glass |
| 아키텍처 | Feature-based Modular + Clean Architecture + Observation |
| 상태 관리 | `@Observable` · `Loadable` |
| 네트워크 | Moya 15 |
| 이미지 | Kingfisher 8 |
| 저장소 | SwiftData (+ CloudKit 폴백) |
| 모듈 · 빌드 | Tuist (mise로 버전 고정) |
| 최소 사양 | iOS 26.0+ · Xcode 26.2 |

## 👬 팀원 소개

### 🥇 1기 · 2025.12.27 – 2026.02.20

| 리버 / 이재원 | 제옹 / 정의찬 | 마티 / 김미주 | 소피 / 이예지 |
|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/a4ddee14-419e-41da-a89a-e2c2fb23a03f" width="200"> | <img src="https://github.com/user-attachments/assets/00ba6ec3-d252-4e93-b467-b0d0ba654fb4" width="200"> | <img src="https://github.com/user-attachments/assets/7842f405-80c3-4394-8978-617c020f47d5" width="200"> | <img src="https://github.com/user-attachments/assets/1749df32-f292-4613-916d-b88cf2390cd2" width="200"> |
| PL | iOS · PM | iOS | iOS |
| [@jwon0523](https://github.com/jwon0523) | [@JEONG-J](https://github.com/JEONG-J) | [@alwn8918](https://github.com/alwn8918) | [@LeeYeJi546](https://github.com/LeeYeJi546) |

### 🥈 2기 · 진행 예정

| 제옹 / 정의찬 | 리버 / 이재원 | 소피 / 이예지 | 원 / 김동민 | 도도 / 김도연 |
|:---:|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/00ba6ec3-d252-4e93-b467-b0d0ba654fb4" width="200"> | <img src="https://github.com/user-attachments/assets/a4ddee14-419e-41da-a89a-e2c2fb23a03f" width="200"> | <img src="https://github.com/user-attachments/assets/1749df32-f292-4613-916d-b88cf2390cd2" width="200"> | _사진 추후 추가_ | _사진 추후 추가_ |
| PL | iOS | iOS | iOS | iOS |
| [@JEONG-J](https://github.com/JEONG-J) | [@jwon0523](https://github.com/jwon0523) | [@LeeYeJi546](https://github.com/LeeYeJi546) | _추후 추가_ | _추후 추가_ |

> 기수별 신규 기능·운영 기록은 [기수 & 릴리스 히스토리](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Release-History)에서 누적 관리합니다.

## 📚 개발 문서 (Wiki)

아키텍처·코딩 컨벤션·빌드 방법 등 상세 가이드는 모두 **[Wiki](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki)** 로 이관했습니다.

| 주제 | 문서 |
|------|------|
| 🏗️ 아키텍처 | [Architecture](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Architecture) |
| 📐 절대 규칙 & 코딩 컨벤션 | [Coding Conventions](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Coding-Conventions) |
| ⚠️ 에러 처리 | [Error Handling](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Error-Handling) |
| 🌐 네트워크 & DTO 디코딩 | [Networking](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Networking) |
| 🎨 디자인 시스템 | [Design System](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Design-System) |
| 🧱 모듈 구조 (Tuist) | [Module Structure](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Module-Structure) |
| ⚙️ 빌드 & 실행 | [Build & Run](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Build-and-Run) |
| 🔀 Git 워크플로우 | [Git Workflow](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Git-Workflow) |

> 신규 합류자는 [Wiki Home](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki) → **빌드 & 실행** 순서로 시작하세요.

## 🔑 시크릿 설정

- `Secrets.xcconfig`(`BASE_URL`, `KAKAO_KEY`)와 `GoogleService-Info.plist`는 **팀 내부 채널**에서 수령합니다.
- 실제 키·설정 파일은 원격 저장소에 커밋하지 않습니다.
- 상세 절차: [Build & Run › 시크릿 설정](https://github.com/UMC-PRODUCT/umc-product-iOS/wiki/Build-and-Run)

---

<div align="center">

**Made with ❤️ by UMC Product Team · iOS**

</div>
