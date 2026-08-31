# 근거리 명함 교환 — 조직 팀 App ID 서명 · 실기기 2대 검증 절차

근거리 명함 교환(MultipeerConnectivity + NearbyInteraction + 로컬 네트워크)을 **실기기 2대로
처음부터 끝까지 검증하는 절차**와, 그 전제인 조직 팀(`8B8B4462NV`) App ID capability 목록을
정리한다. 팀원 1명이 이 문서만 보고 검증을 재현할 수 있는 것이 목표다.

> **현재 상태 (이슈 #1241)**: Apple Developer 포털의 App ID capability 반영은 포털 접근 권한이
> 있는 **메인테이너가 직접 수행해야 한다** — 코드로 끝낼 수 없는 blocked 항목이다. 이 문서의
> 3장 체크리스트가 그 작업 목록이고, 포털 화면에서의 실제 확인이 필요한 부분은 본문에 표시했다.

- 작성자: 제옹(euijjang97)
- 기준 코드:
  - `UMCApp/Project.swift`
  - `UMCApp/UMCApp.entitlements`
  - `UMCApp/Tuist/ProjectDescriptionHelpers/Settings+Recommended.swift`
  - `UMCApp/Scripts/verify-secrets.sh`
  - `UMCApp/Core/NearbyExchange/Sources/Transports/MPCTransport.swift`
  - `UMCApp/Core/NearbyExchange/Sources/Ranging/PeerRangingCoordinator.swift`
  - `UMCApp/UMCApp/Sources/RootTab/RootTabView.swift`
  - `UMCApp/UMCApp/Sources/DIContainer+BusinessCard.swift`
  - `UMCApp/UMCApp/Sources/Debug/BusinessCard/` (검증 하네스 전체)
  - `UMCApp/UMCApp/Sources/Debug/DebugFileLog.swift`
  - `UMCApp/UMCApp/Sources/Debug/StubSession/StubSessionMode.swift`

## 1) 이 문서가 필요한 이유

근거리 교환은 **시뮬레이터로 검증할 수 없다.**

- 시뮬레이터에는 실제 무선(Wi-Fi P2P·Bluetooth)이 없어 MPC 발견·연결이 돌지 않는다.
  그래서 시뮬레이터 DEBUG 빌드는 `MockNearbyTransport` 가 주입되어 흐름만 돈다
  (`UMCApp/UMCApp/Sources/Debug/BusinessCard/NearbyTransportChoice.swift:47-57`).
- UWB(NearbyInteraction)는 시뮬레이터에 아예 존재하지 않고, QR 스캔용
  `DataScannerViewController` 도 시뮬레이터 미지원이다
  (`UMCApp/UMCApp/Sources/Debug/BusinessCard/DebugToolsView.swift:20-33` 의 정리 표 참고).

즉 제품 경로(MPC 발견 → 초대 타이브레이크 → 핸드셰이크 → 명함 왕복 → UWB 거리)는 **실기기
2대가 있어야만** 확인된다. 그런데 조직 팀 App ID 에 필요한 capability 가 정리되어 있지 않으면
Automatic signing 이 프로비저닝 프로파일을 받지 못해 실기기 설치 자체가 막힌다 — 그 정리
목록(3장)과 검증 절차(5장)를 한 문서로 묶는다.

## 2) 필요 기기 조건

### 2-1) 공통 전제 (2대 모두)

- **iOS 26.4 이상** — Deployment Target (`UMCApp/Project.swift:15`)
- **Debug 빌드** — 검증 하네스 전체가 `#if DEBUG` 라 릴리스 빌드에는 없다
- **Wi-Fi · Bluetooth 켜짐** — MPC 는 이 둘 위에서 피어를 찾는다. 같은 Wi-Fi 에 붙이는 것이
  가장 안정적이다 (에어플레인 모드 금지)
- **로컬 네트워크 권한 허용** — 첫 교환 세션 시작 때 팝업이 뜬다. 거부하면 발견·광고가
  둘 다 실패한다 (`UMCApp/Project.swift:44-52` 의 `NSLocalNetworkUsageDescription` /
  `NSBonjourServices` 선언 근거)

### 2-2) UWB(거리 표시) 요건

거리 표시는 `PeerRangingCoordinator.isSupported`
(`NISession.deviceCapabilities.supportsPreciseDistanceMeasurement`)가 참인 기기끼리만 된다 —
**iPhone 11 미만과 iPad 는 `false`** (U1/U2 칩 미탑재,
`UMCApp/Core/NearbyExchange/Sources/Ranging/PeerRangingCoordinator.swift:52-59`).

NI 는 **대칭**이다. 양쪽이 서로의 `discoveryToken` 으로 세션을 실행해야 값이 나오고, 한쪽만
실행하면 **양쪽 다** 아무것도 받지 못한다 (같은 파일 43-47행 주석 — 2026-08-16 실기기 검증에서
이 조건을 몰라 한참 헤맸고, 그래서 제품 경로는 MPC 연결 시 토큰 교환을 자동화했다).
UWB 미탑재 기기는 토큰 없이 미리보기만 보내고, 받는 쪽은 행을 그리되 거리 칸을 비운다
(`PeerRangingCoordinator.swift:149-181`, `makeHandshake(forPeerID:)`).

### 2-3) 기기 조합별 검증 가능 범위

기기가 부족해도 UWB 를 제외한 전부를 검증할 수 있다. 조합별로 어디까지 되는지:

| 검증 항목 | UWB 2대 | UWB 1대 + 미탑재 1대 | 미탑재 2대 |
|---|---|---|---|
| MPC 발견 · 자동 초대 · 연결 | O | O | O |
| 명함 전송 · 맞교환 · 명함첩 저장 | O | O | O |
| QR 스캔 교환 | O | O | O |
| 거리 표시 (「2.1m」 · 신호 막대) | O | **X** (NI 대칭 — 한쪽만으로는 불가) | X |
| UWB 단독 검증 (5-3 절차) | O | X | X |

미탑재 기기의 행은 거리 칸이 「—」 로 고정된다 — 이것은 정상이지 버그가 아니다
(`DebugNearbyExchangeView.swift:191-206` 이 의도적으로 막대를 그리지 않는다).

## 3) 조직 팀 `8B8B4462NV` App ID capability 체크리스트

서명 설정은 매니페스트에 고정되어 있다
(`UMCApp/Tuist/ProjectDescriptionHelpers/Settings+Recommended.swift:37-38`):

```swift
"DEVELOPMENT_TEAM": "8B8B4462NV",
"CODE_SIGN_STYLE": "Automatic",
```

Automatic signing 이 프로파일을 받으려면 **포털의 App ID 에 entitlements 파일이 요구하는
capability 가 전부 켜져 있어야 한다.** 아래 목록은 `UMCApp/UMCApp.entitlements` 실제 내용에서
역산한 것이다. 포털 경로: Certificates, Identifiers & Profiles → Identifiers →
`com.umc.product` (App Store 기존 앱 레코드와 같은 Bundle ID — 바꾸면 카카오/Firebase/Google
OAuth 등록이 전부 무효화된다, `UMCApp/Project.swift:12-14`).

> 아래 체크박스의 실제 on/off 상태는 **포털에서 직접 확인해야 한다** — 이 레포에서는
> entitlements 파일로 "무엇이 필요한지"까지만 확정할 수 있다.

### 3-1) App ID `com.umc.product` (앱 타겟)

- [ ] **Push Notifications** — entitlement `aps-environment`
  (`$(APS_ENVIRONMENT)`, `Secrets/Shared.xcconfig:25-26` 에서 Debug=development /
  Release=production 주입)
- [ ] **Sign In with Apple** — entitlement `com.apple.developer.applesignin` (`[Default]`)
- [ ] **iCloud → CloudKit** — entitlement `com.apple.developer.icloud-services` (`[CloudKit]`)
  - ★ 별도 식별자 생성·연결 필요: **iCloud Container `iCloud.com.umc.product`**
    (entitlement `com.apple.developer.icloud-container-identifiers`). 포털의
    Identifiers → iCloud Containers 에서 만들고 App ID 에 연결한다
- [ ] **Nearby Interaction** — entitlement `com.apple.developer.nearby-interaction` (`true`)
  — **이번 이슈(#1241)의 핵심 항목.** 꺼져 있으면 UWB 거리 검증이 서명 단계에서 막힌다
- [ ] **App Groups** — entitlement `com.apple.security.application-groups`
  - ★ 별도 식별자 생성·연결 필요: **App Group `group.com.umc.product.widget`**
    (포털의 Identifiers → App Groups 에서 만들고 App ID 에 연결한다)

### 3-2) 부속 타겟 App ID

실기기 설치는 임베드 타겟까지 전부 서명하므로 이들의 App ID 도 팀에 있어야 한다:

- [ ] **`com.umc.product.widget`** (Widget Extension) — **App Groups** 켜고 같은
  `group.com.umc.product.widget` 연결 (`UMCApp/UMCAppWidget/UMCAppWidget.entitlements`)
- [ ] **`com.umc.product.watchkitapp`** (watchOS) — 별도 entitlements 파일 없음
  (`UMCApp/UMCWatchApp/Project.swift:6`), App ID 존재만 확인

### 3-3) 포털에서 켤 것이 **없는** 항목

다음은 App ID capability 가 아니라 **Info.plist 키만으로 동작한다** — 포털에서 스위치를
찾아 헤매지 않아도 된다 (`UMCApp/Project.swift:33-52`):

- 로컬 네트워크 / Bonjour (`NSLocalNetworkUsageDescription`, `NSBonjourServices`)
- 카메라 (`NSCameraUsageDescription`), 사진 추가 (`NSPhotoLibraryAddUsageDescription`)
- 위치 (`NSLocationWhenInUseUsageDescription`)
- Nearby Interaction 의 **권한 문구** (`NSNearbyInteractionUsageDescription`) — 문구는
  Info.plist, capability 는 3-1 의 entitlement. 둘 다 있어야 한다

## 4) Xcode 쪽 준비

1. **프로젝트 열기** — 항상 Makefile 경유로:

   ```bash
   cd UMCApp && make open      # generate + Xcode 열기
   ```

2. **기기 등록** — 처음 쓰는 기기는 맥에 USB/무선으로 연결하고 Xcode → Window → Devices and
   Simulators 에서 인식시킨다. Automatic signing 이 조직 팀 계정으로 기기를 포털 Devices 에
   등록하고 프로파일을 받아온다. 안 되면 포털의 Devices 에 UDID 수동 등록이 필요할 수 있다
   (포털에서 직접 확인 필요 — 조직 계정의 기기 등록 권한은 역할에 따라 다르다).
3. **팀 확인 — Xcode UI 에서 바꾸지 말 것.** Signing & Capabilities 탭에서 Team 이
   `8B8B4462NV` 조직 팀으로 잡혀 있는지 **확인만** 한다. UI 에서 팀을 골라도
   `tuist generate` 가 `.xcodeproj` 을 재생성하며 날아간다 — 바꿔야 한다면
   `Settings+Recommended.swift` 매니페스트에서만 바꾼다 (같은 파일 27-28행 주석).
4. **시크릿** — `Scripts/verify-secrets.sh` 는 Release 빌드에서만 시크릿
   (`Secrets/Secrets.xcconfig` 의 `KAKAO_KEY` 등 4종 + `GoogleService-Info.plist`) 누락 시
   빌드를 중단하고, **Debug 는 경고만 남기고 통과한다** (`verify-secrets.sh:15-19`).
   이 검증은 Debug 빌드라 시크릿 없이도 설치·실행이 되지만, 카카오 로그인·FCM 은 동작하지
   않는다 — 기본 stub 세션(4-5)이라 교환 검증에는 지장이 없다.
5. **스킴 실행 인자 `-bcHarness`** — 검증 하네스의 **유일한 진입 경로**다. Product → Scheme →
   Edit Scheme… → Run → Arguments Passed On Launch 에 `-bcHarness` 를 추가한다. 앱 시작 시
   마이페이지 탭 위에 검증 화면이 push 된다
   (`UMCApp/UMCApp/Sources/RootTab/RootTabView.swift:79-84`). 스킴도 generate 대상이므로
   `make generate` 후에는 인자가 사라졌는지 확인하고 다시 넣는다.
6. **세션 모드** — DEBUG 기본값은 stub 세션이라 **로그인 없이** 홈에 진입하고, 내 명함도
   `StubMemberProfileRepository` 의 stub 프로필로 로드된다
   (`UMCApp/UMCApp/Sources/Debug/StubSession/DIContainer+StubSession.swift:31-33`).
   교환 검증은 stub 세션으로 충분하다. 실서버 응답이 필요한 검증(QR 딥링크 조회)만
   실행 인자 `-realSession` 또는 검증 도구의 토글로 전환한다
   (`StubSessionMode.swift:19-27` — 전환은 앱 재시작 후 반영).

## 5) 실기기 2대 검증 절차

두 기기를 **A / B** 로 부른다. 별도 표기가 없으면 양쪽 모두 같은 단계를 수행한다.

### 5-1) 설치와 하네스 진입

1. A·B 각각을 run destination 으로 골라 Debug 빌드를 설치·실행한다
   (`-bcHarness` 인자 포함 — 4장 5번).
   - **기대**: 앱이 뜨고 마이페이지 탭에 「마이페이지」 검증 화면이 자동으로 push 된다.
     상단에 명함 카드(이름/닉네임·파트·기수 칩)가 로드된다. 카드가 「명함 로드 실패」면
     5-4 트러블슈팅이 아니라 세션 모드(4장 6번)부터 확인한다 — 명함 없이는 교환을 시작할 수
     없다 (`BusinessCardDebugViewModel.swift:265-268`).
2. 명함 카드의 **「명함 교환」** 버튼 → `DebugExchangeView` 진입.
   - **기대**: 「전송 방식」 세그먼트가 **MPC (권장)** 이고 「주입된 transport」 가
     `MPCTransport` 다. 실기기 기본값이 MPC 라 보통 손댈 것이 없다
     (`NearbyTransportChoice.swift:47-57`). `MockNearbyTransport` 로 보이면 피커에서 MPC 를
     고르고 **앱을 다시 켠다** — DI 가 시작 시 한 번만 읽는다.

### 5-2) MPC 발견 → 연결 → 명함 왕복 (제품 경로 전체)

3. 양쪽 모두 「시안 배치로 보기」 → `DebugNearbyExchangeView` 진입. 진입 즉시 교환 세션이
   자동 시작된다 (`DebugNearbyExchangeView.swift:60-63`).
   - **기대(최초 1회)**: 「로컬 네트워크」 권한 팝업 → **허용**. 거부하면 레이더에서 영영
     멈춘다.
   - **기대**: 하단 진단 영역에 「이 기기 — iPhone17,3 · a1b2…」 형식의 자기 식별이 뜨고,
     우측 `·N` 숫자가 0.5초마다 돈다(폴링 생존 표시 — 멈춰 있으면 아래 값을 믿지 말 것).
4. 잠시(수 초) 기다린다.
   - **기대**: 양쪽 목록에 상대 행이 뜬다 — 이름/닉네임 · 파트 · 기수, 그 아래 작은 글씨로
     상대 기기 모델(`iPhone17,3` 등)과 상태 점. 점이 **초록**이면 세션 연결까지 완료다
     (주황 = 발견만 됨). 진단 영역이 「연결됨 1 / 발견 1」 이 되면 성공.
   - 발견·초대·수락·핸드셰이크는 전부 자동이다: 세션 식별자가 작은 쪽이 초대를 맡고
     (`MPCTransport.swift:404-419`), 받는 쪽은 자동 수락하며(:570-579), 연결되는 순간
     NI 토큰 핸드셰이크가 오간다(:690-702). **이 단계에서 명함은 나가지 않는다.**
5. UWB 기기 2대라면 — 연결 후 몇 초 안에 행 우측에 거리(「0.4m」)와 신호 막대가 뜬다.
   - **기대**: 두 기기를 멀리/가까이 움직이면 값이 따라 변한다. 「—」 로 남으면 2-3 표와
     6장 「거리 값이 안 나옴」 을 본다.
6. **A 에서** 상대 행을 탭한다 — 명함 전송은 탭이 있어야만 일어난다
   (`MPCTransport.swift:268-287`).
   - **기대(A)**: 행 아래 「전송 중…」 → **「전송 완료 — 명함첩 확인」**.
   - **기대(B)**: 명함이 도착하고, 맞교환 회신(연결당 1회, `MPCTransport.swift:732-737`)으로
     **A 에도 B 의 명함이 돌아온다** — 즉 한 번의 탭으로 양쪽 명함첩에 서로가 저장된다.
7. 「교환 중지」 → 뒤로 → 검증 화면의 「받은 명함」 행(또는 툴바 렌치 → 검증 도구의
   「저장된 명함 N장」)에서 카운트를 확인한다.
   - **기대**: 양쪽 모두 상대 명함이 1장 늘었다. **앱을 완전히 종료 후 다시 켜도** 남아 있다
     (SwiftData 영속 확인). 같은 상대와 다시 교환하면 새 행이 아니라 갱신(upsert)이다.

### 5-3) UWB 단독 검증 (선택 — MPC 를 빼고 NI 만)

MPC 와 NI 를 분리해서 봐야 할 때만 수행한다. 검증 화면 툴바의 렌치 아이콘 →
「검증 도구」 → **「UWB — Nearby Interaction 거리」** 섹션 (`NearbyRangingSection.swift`).
제품과 같은 `PeerRangingCoordinator` 를 돌리되 토큰만 QR 로 나른다.

8. 양쪽 모두 「UWB 지원 true」 인지 먼저 확인한다 (한쪽이라도 false 면 이 절차는 불가).
9. 양쪽 모두 「내 토큰 QR 만들기」.
   - **기대**: QR 과 함께 「내 토큰」 지문(6자리 hex)이 뜬다.
   - ⚠️ 버튼을 다시 누르면 재생성이 막힌다 — 새 토큰을 만들면 상대가 이미 스캔한 토큰이
     통째로 무효가 되기 때문이다 (`NearbyRangingSection.swift:133-140`). 다시 만들려면
     「세션 종료」 후 처음부터.
10. **서로의** 화면에 뜬 QR 을 교차 스캔한다 (A 가 B 의 QR 을, B 가 A 의 QR 을).
    - **기대**: A 의 「내 토큰」 지문 == B 의 「상대 토큰」 지문 (그 반대도 동일).
      자기 QR 을 자기가 찍으면 「⚠️ 내 토큰을 스캔했다」 경고가 뜬다.
    - **기대**: **양쪽 모두** 스캔을 마치면 「레인징 실행 중」 「거리 N.NN m」 「갱신 수신
      N회」 가 오르기 시작한다. **한쪽만 스캔한 상태에서는 양쪽 다 0회다** — NI 대칭(2-2)
      그대로다. 이것이 이 섹션이 존재하는 이유다.

### 5-4) 로그 회수 (실패 분석용)

하네스는 화면과 동시에 파일로도 로그를 남긴다 (`DebugFileLog.swift`). 맥에서 꺼내는 명령은
같은 파일 17-21행 주석에 문서화되어 있다:

```bash
xcrun devicectl device copy from --device <id> \
  --domain-type appDataContainer --domain-identifier dev.umc.product.debug \
  --source "Library/Caches/umc-debug-events.log" --destination .
```

위 `dev.umc.product.debug` 는 주석 원문 그대로다. `--domain-identifier` 는 앱의 Bundle ID 를
받으므로 이 값은 실제 Bundle ID(`com.umc.product`)와 다르다 — 실패하면 `com.umc.product` 로
바꿔서 다시 시도하고, 그래도 안 되면 `xcrun devicectl device info apps` 출력에서 컨테이너를
찾는다. 파일 경로(`Library/Caches/umc-debug-events.log`)는 어느 쪽이든 같다.

## 6) 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| 서명 실패 — "provisioning profile doesn't include the … entitlement" | App ID 에 대응 capability 미활성 (특히 Nearby Interaction) | 3장 체크리스트대로 포털에서 켜고 Xcode 에서 다시 빌드 (Automatic 이 프로파일을 재발급) |
| 서명 실패 — 기기가 프로파일에 없음 | 기기 미등록 | 4장 2번 — Devices and Simulators 인식 또는 포털 Devices 등록 |
| 빌드마다 서명 팀이 풀림 | Xcode UI 에서 팀을 바꿈 → `tuist generate` 가 재생성하며 유실 | UI 에서 바꾸지 않는다. `Settings+Recommended.swift:37-38` 이 유일한 진실 원천 |
| 피어가 서로 안 보임 (레이더에서 멈춤) | 로컬 네트워크 권한 거부 | 설정 → 개인 정보 보호 및 보안 → 로컬 네트워크에서 UMC 허용 후 재시도. 진단 영역의 transport 실패 원문(빨간 글씨)으로 브라우저/광고 실패 여부를 가른다 (`MPCTransport.swift:581-589`, `:644-653`) |
| 〃 | `NSBonjourServices` 와 `MPCTransport.serviceType` 불일치 — 브라우저·광고가 **둘 다 조용히 실패**한다 | `UMCApp/Project.swift:49-52` (`_umc-card._tcp/_udp`) 와 `MPCTransport.swift:43` (`"umc-card"`) 이 같은지 확인. 둘 중 하나만 고친 커밋이 없는지 본다 |
| 〃 | 다른 네트워크 / Wi-Fi·BT 꺼짐 / 에어플레인 모드 | 2-1 전제 복구. 같은 Wi-Fi 에 붙인다 |
| 〃 | `MockNearbyTransport` 가 주입돼 있음 | `DebugExchangeView` 의 「주입된 transport」 확인 → 피커에서 MPC 선택 → **앱 재시작** (DI 는 시작 시 1회만 읽는다) |
| 「연결됨 0」 인데 로그도 안 변함 | 진단 폴링 정지 — transport 값은 계산 프로퍼티라 tick 없이는 화면이 안 바뀐다 (`BusinessCardDebugViewModel.swift:88-100`) | 진단 영역 우측 `·N` 이 도는지 먼저 본다. 멈췄으면 화면을 나갔다 재진입 (고장난 계기를 읽고 "연결 안 됨"으로 오판한 전례가 있다) |
| 거리 값이 안 나옴 (「—」 고정) | NI 비대칭 — 한쪽만 세션 실행 (5-3 에서 한쪽만 스캔했거나, 제품 경로에서 핸드셰이크가 한쪽만 도착) | 5-3 이면 **양쪽 모두** 교차 스캔했는지, 지문이 교차 일치하는지 확인. 제품 경로면 「마지막 오류」·`lastError` 원문 확인 (`PeerRangingCoordinator.swift:184-201`) |
| 〃 | UWB 미탑재 기기 (한쪽이라도) | 2-3 표 — 해당 조합에서는 거리 검증 불가가 정상. `NearbyRangingSection` 의 「UWB 지원」 값으로 판정 |
| 〃 | 앱이 백그라운드로 감 — NI 세션 suspend | 양쪽 다 포그라운드 유지 (`PeerRangingCoordinator.swift:256-262` 가 값을 비운다) |
| 〃 (5-3) | 토큰 재생성 — 상대가 스캔한 토큰이 무효화됨 | 「세션 종료」 후 양쪽 모두 처음부터. 지문 비교로 확인 |
| 권한 팝업이 안 뜸 | 이미 한 번 거부해서 다시 묻지 않음 | 설정 앱에서 해당 권한(로컬 네트워크·카메라·Nearby Interaction)을 직접 켠다. 그래도 안 되면 앱 삭제 후 재설치로 권한 상태 초기화 |
| 전송은 되는데 수신이 안 됨 | `startAdvertising()` 이 수신 continuation 을 닫는 회귀 (`MPCTransport.swift:183-189` 주석의 함정) | 최신 develop 빌드인지 확인. 재발이면 해당 주석 지점을 의심 |
| 첫 탭은 20초 뒤 실패, 두 번째 탭은 성공 | 초대 경쟁 — 타이브레이크를 무시한 구버전 증상 (`MPCTransport.swift:395-403` 주석) | 현재 코드는 `inviteIfNeeded` 단일 경로로 해결됨. 이 증상이 보이면 구 빌드가 설치된 것 |
| 「내 명함이 없어 교환을 시작할 수 없다」 | 내 명함 로드 실패 — 실서버 세션 강제 상태에서 미로그인 등 | 검증 도구 → 「memberId로 명함 조회」 의 세션 모드 확인. stub 로 되돌리고 앱 재시작 (4장 6번) |

## 7) 관련 파일

| 역할 | 경로 |
|---|---|
| 서명 설정 (`DEVELOPMENT_TEAM`·`CODE_SIGN_STYLE`) | `UMCApp/Tuist/ProjectDescriptionHelpers/Settings+Recommended.swift:37-38` |
| Bundle ID · Info.plist 권한 키 · `NSBonjourServices` | `UMCApp/Project.swift:14`, `:33-52` |
| 앱 entitlements (capability 근거) | `UMCApp/UMCApp.entitlements` |
| 위젯 entitlements (App Group) | `UMCApp/UMCAppWidget/UMCAppWidget.entitlements` |
| `APS_ENVIRONMENT` 주입 | `UMCApp/Secrets/Shared.xcconfig:25-26` |
| 시크릿 검증 (Release 중단 / Debug 경고) | `UMCApp/Scripts/verify-secrets.sh:15-19` |
| MPC transport (`serviceType`·초대 타이브레이크·핸드셰이크) | `UMCApp/Core/NearbyExchange/Sources/Transports/MPCTransport.swift:43`, `:404-419`, `:690-702` |
| UWB 조율 (`isSupported`·대칭 조건·피어당 세션 1개) | `UMCApp/Core/NearbyExchange/Sources/Ranging/PeerRangingCoordinator.swift:37-59` |
| 하네스 진입 (`-bcHarness`) | `UMCApp/UMCApp/Sources/RootTab/RootTabView.swift:79-84` |
| transport 주입 (실기기 MPC / 시뮬레이터 Mock) | `UMCApp/UMCApp/Sources/DIContainer+BusinessCard.swift:25-35` |
| 검증 화면 (명함 카드 → 「명함 교환」) | `UMCApp/UMCApp/Sources/Debug/BusinessCard/BusinessCardDebugView.swift` |
| 전송 계층 선택 · 세션 시작 | `UMCApp/UMCApp/Sources/Debug/BusinessCard/DebugExchangeView.swift` |
| 시안 배치 교환 화면 (자동 세션 · 진단 영역) | `UMCApp/UMCApp/Sources/Debug/BusinessCard/DebugNearbyExchangeView.swift` |
| UWB 단독 검증 섹션 (QR 토큰 채널) | `UMCApp/UMCApp/Sources/Debug/BusinessCard/NearbyRangingSection.swift` |
| 파일 로그 · `devicectl` 회수 명령 | `UMCApp/UMCApp/Sources/Debug/DebugFileLog.swift:17-21` |
| stub 세션 토글 (`-realSession`) | `UMCApp/UMCApp/Sources/Debug/StubSession/StubSessionMode.swift:19-27` |
