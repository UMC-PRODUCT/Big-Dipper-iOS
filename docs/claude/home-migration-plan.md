# Home 마이그레이션 잔여 검토

> 레거시 `AppProduct/AppProduct/Features/Home/` → Tuist `UMCApp/Features/Home/` 이관의
> **현재 잔여 범위**를 파일·라인 단위로 확정한 문서입니다.
> 조사 시점: `develop` (`fa6c7237`, 2026-08-09).
>
> - `AppProduct/` 는 v2.2.0 동결 — **열람만 했고 수정하지 않았습니다** (절대 규칙 #9).
> - 인용은 `path:line` 형식입니다. 확정 근거가 없는 판단은 **추정**으로 표기했습니다.

- 작성자: 제옹(euijjang97)

## ✅ 처리 현황 (2026-08-09 작업 트리 반영)

아래 §1~§3 의 잔여 항목 **17건 전부**를 `develop` 작업 트리에 구현했습니다. 커밋 전 상태입니다.

| 이슈 | 범위 | 상태 |
|---|---|---|
| #J | 참여자 선택 결선 (작성자 강제 포함) | ✅ |
| #K | ScheduleCapabilities 결선 + `maxParticipantCount` `String` 교정 + StubSession 등록 | ✅ |
| #L | 시작된 일정 편집 사전 차단 + 잠금 배너 + 삭제 진행 표시 | ✅ |
| #M | 최근 공지 섹션 에러/재시도 복원 + 재시도 스피너 결선 + `LoadingView` | ✅ |
| #N | 홈 진입 프로필 저장 — `SyncProfileStorageUseCase` **CoreDomain 승격** 후 결선 | ✅ |
| #O | 분류 게이트 + `TaskGroup` 병렬화, AI 실패 인라인 표시, 키보드 내림, `Equatable` 복원 | ✅ |
| #P | `ScheduleRegistrationViewModelTests` 신규 (12) + 상세 4 suite | ✅ |
| #Q | `tuist-file-mapping.md` Home 구간 32행 동기화 | ✅ |
| #R | Preview `#if DEBUG` 가드 — 저장소 전역 **잔여 0** | ✅ |
| — | `PointLog.point` 절삭 버그 (`-0.5 → 0`) | ✅ |

**검증**: `tuist generate` 성공(순환 의존 없음) · `make build` **BUILD SUCCEEDED** ·
테스트 전부 통과 — HomeDomain 19 / HomeData 34 / HomePresentation 36 / UMCAppTests 14 /
CoreDomain 9 / AuthDomain 51 / AuthPresentation 102 / ActivityDomain 218 / ActivityPresentation 295 /
CoreUIComponents 29. `git status AppProduct/` 무변경.

### 원안과 달라진 판단 4건

1. **`PointLog.point` 은 `String` 이 아니라 `Double` 유지 + 절삭 제거.**
   원본 `ProfileChallengerPoint.point` 자체가 `Double`(`decodeDoubleFlexible`) 이라 절대 규칙 #2
   ("서버 응답 **정수**") 범위 밖입니다. `String` 전환은 숫자 리터럴 생성부 4곳을 깨뜨리기만 하고
   얻는 게 없습니다. 표시는 `.number.precision(.fractionLength(0...1))`.
2. **Activity Challenger 컴포넌트는 `SelectedChallengerView` 1개만 `public` 승격.**
   나머지 3개는 `some View` 뒤에 가려져 Home 에서 직접 참조되지 않습니다 — 공개 API 표면을 늘리지 않았습니다.
3. **`SyncProfileStorageUseCase` 는 CoreDomain 승격.** Home→AuthDomain 은 의존 방향이 잘못됐고,
   이 UseCase 는 CoreDomain/UMCFoundation 타입에만 의존해 승격 비용이 0(기존 소비처 import 수정 0건)입니다.
4. **중복 DTO(`ScheduleLocationDTO`/`ScheduleAttendancePolicyDTO`) 통합은 보류** — §3-7 참조.

### 후속으로 남긴 것

- **중복 DTO 통합**: Home·Activity 사본이 동작상 동일하고 소비처가 각각 1곳뿐이지만, Activity 사본을
  지우려면 `ActivityData → HomeData` 라는 Feature 간 Data-to-Data 의존을 새로 만들어야 합니다.
  40줄 중복을 없애려고 레이어 경계를 뚫는 건 손해라 별도 이슈로 분리. 대안은 두 DTO 의 CoreNetwork 승격.
- **출석 정책 피커 6개 키보드 내림**: `Core/UIComponents/.../AttendancePolicyTimeSection.swift` 의
  `@State private var openSlot` 이 컴포넌트 내부라 외부에서 토글을 관측할 수 없습니다. 시작/종료 4개만 결선됨.
- **`LoadingType.Home` 에 일정 로딩 케이스 부재**: 기존 3종은 문구가 고정이라 일정 게이트에는
  무문구 플레이스홀더를 남겼습니다. 케이스 추가는 CoreUIComponents 변경 건.
- **`tuist-file-mapping.md` 상단 "목적지별 파일 수" 요약** 미갱신 (766행 전수 재집계 필요).

---

## 0. 요약 — 파일 이관은 끝났고, 남은 건 "결선(wiring)"입니다

초판 계획서의 그룹 A~I는 **전부 머지 완료**입니다.

| 그룹 | 내용 | 머지 커밋 |
|---|---|---|
| A | 일정 권한(capabilities) 조회 체인 | `1eb39f89` (#1115) |
| B | 일정 등록 화면·ViewModel + 라우팅 | `e1a04a19` (#1106) |
| E·G | 일정 수정·삭제·강제 삭제 파이프라인 | `841d4968` (#1102) |
| F | Core Authorization 이관 + Notice 스텁 제거 | `dba14433` (#1101) |
| H | 캘린더 가로(horizon) 모드 + 모드 토글 | `18b07c73` (#1109) |
| I | ChallengerGenRepository 구현체 + GenerationMappingRecord | `b5441162` (#1099) |
| — | 일정 상세 수정(연필) 진입점 결선 | `1020a017` (#1114) |

**따라서 "미이식 파일"은 사실상 0입니다.** 남은 문제는 전부 다른 성격입니다:

1. **결선되지 않은 파이프라인** — 타입·Repository·UseCase·DI 등록까지 다 만들어 놓고 소비처가 0인 코드
2. **화면 안에서 빠진 기능** — 파일은 이관됐지만 섹션/분기가 누락
3. **규약 위반·테스트 공백** — 이관 과정에서 들어온 부채

잔여 항목은 **P0 기능 결손 5건 / P1 UX·성능 열화 7건 / P2 규약·부채 5건**입니다.

---

## 1. P0 — 기능 결손 (사용자에게 보이는 동작 차이)

### 1-1. ⛔ 참여자 선택이 통째로 없다 — 생성되는 일정에 참여자가 0명

가장 큰 결손이며, 다른 어떤 항목보다 먼저 처리해야 합니다.

| 지점 | 현재 상태 |
|---|---|
| 등록 화면 참여자 섹션 | **없음**. 주석만 존재 — `UMCApp/Features/Home/Presentation/Sources/Views/Registration/ScheduleRegistrationView.swift:212-213` |
| 생성 요청 | `participantMemberIds: []` **하드코딩** — `.../ViewModels/ScheduleRegistrationViewModel.swift:443` |
| 수정 요청 | `participantMemberIds: nil` (서버 값 보존) — 같은 파일 `:488`. 편집으로 참여자를 바꿀 방법이 없음 |
| 편집 prefill | 참여자 조회 자체가 없음 — `applyPrefill` 이 건너뜀 (`:228-229`) |
| 변경 감지 | `EditFormSnapshot` 에 `participantMemberIds` 없음 → 참여자 편집이 폼을 dirty 로 만들지 못함 |

레거시는 `sanitizedParticipantMemberIds()` 에서 **작성자 본인 memberId 를 강제 포함**했습니다
(`AppProduct/.../ScheduleRegistrationViewModel.swift:614-621`). 지금 UMCApp 이 만드는 일정은
**작성자조차 참여자에 없습니다.**

**차단 요인 2개 (둘 다 확인됨):**

1. Activity 의 챌린저 컴포넌트 4종이 전부 `internal` —
   `UMCApp/Features/Activity/Presentation/Sources/Components/Challenger/SearchChallengerView.swift:22`,
   `SelectedChallengerView.swift:19`, `ChallengerFormView.swift:16`, `ChallengerSearchCard.swift:17`
   (각 `init` 도 internal).
2. `UMCApp/Features/Home/Project.swift:18-31` (`presentationExtraDependencies`) 에
   `ActivityPresentation`·`ActivityDomain` 이 **없음**.

`CoreDomain.ChallengerInfo` 는 이미 `public` 이므로(`UMCApp/Core/Domain/Sources/Member/ChallengerInfo.swift:14`)
막는 건 뷰 접근 제어자와 모듈 의존 2개뿐입니다.

> **설계 결정 유지**: Core 승격이 아니라 Feature→Feature 의존을 택합니다.
> 소비 Feature 가 3개가 되면 그때 `CoreUIComponents` 로 올립니다.

### 1-2. ⛔ `ScheduleCapabilities` 파이프라인이 소비처 0 — 만들어만 두고 아무도 안 쓴다

`1eb39f89` 로 DTO·Repository·UseCase·DI 등록(`UMCApp/UMCApp/Sources/DIContainer+Home.swift:55-62`)까지
전부 들어왔지만, **Presentation 전체에서 `resolve` 하는 곳이 한 군데도 없습니다.**
`grep -rn "Capabilities" UMCApp/Features/Home/Presentation/` 의 유일한 히트가
"이식하지 않았다"고 적힌 주석입니다 (`ScheduleRegistrationView.swift:183`).

그 결과 레거시에 있던 두 게이트가 모두 빠졌습니다:

| 레거시 동작 | 근거 | UMCApp 현재 |
|---|---|---|
| `canCreateAttendanceRequiredSchedule == false` 면 출석 필수 토글을 강제 `false` 로 내리고 섹션 비노출 | `AppProduct/.../ScheduleRegistrationViewModel.swift:348-364`, `ScheduleRegistrationView.swift:726-730` | **토글 무조건 노출** (`ScheduleRegistrationView.swift:183-187`). 권한 없는 사용자는 서버가 거부할 때까지 모름 |
| 참여자 수 `maxParticipantCount` 초과 시 인라인 경고 + 등록 차단, `N / max` 표시 | `AppProduct/.../ScheduleRegistrationViewModel.swift:605-611`(문구), `:507-511`(생성), `:686-691`(수정), `View:601-645`(UI) | **없음** (§1-1 참여자 섹션 부재의 종속 항목) |

레거시는 `loadCapabilities()` 를 `.task` 에서 호출했습니다 (`AppProduct/.../ScheduleRegistrationView.swift:86`).

### 1-3. ⛔ 이미 시작된 일정도 편집 화면이 열린다

`ScheduleDetailViewModel.isScheduleStarted` 는 정의돼 있지만
(`UMCApp/Features/Home/Presentation/Sources/ViewModels/ScheduleDetailViewModel.swift:47`)
**저장소 전체에서 이 프로퍼티를 읽는 곳이 없습니다** (`grep -rn "isScheduleStarted" UMCApp/` 결과 1건 = 선언부).

- 레거시는 연필 버튼을 비활성화하고 a11y label/hint 를 바꿨습니다 (`AppProduct/.../ScheduleDetailView.swift:121-127`).
- 레거시 상세 화면 상단의 **"이미 시작된 일정은 수정할 수 없습니다" 잠금 배너**도 빠졌습니다
  (`AppProduct/.../ScheduleDetailView.swift:306-312` ↔ 마이그레이션판 `topContent:190-198` 은 이름·장소·날짜만).
- UMCApp 은 편집 메뉴를 무조건 만듭니다 (`UMCApp/.../Views/ScheduleDetailView.swift:125-133`).

등록 ViewModel 쪽 `SCHEDULE-0028`(이미 시작된 일정) 처리는 살아 있으므로
(`ScheduleRegistrationViewModel.swift:498-500`), 지금은 **사용자가 편집 화면을 다 채운 뒤 저장에서 거부당하는** 흐름입니다.
사전 차단으로 승격해야 합니다.

### 1-4. ⛔ 최근 공지 조회 실패가 화면에서 완전히 사라진다

```swift
case .failed:
    EmptyView()          // UMCApp/Features/Home/Presentation/Sources/Views/HomeView.swift:213-214
```

"최근 공지" 섹션 헤더 자체가 `recentNoticeLoaded` 안에 있어(`HomeView.swift:250`)
실패 시 **헤더까지 통째로 증발**합니다. 에러 표시도 재시도 버튼도 없습니다.

`recentNoticeState` 는 season 이 `.loaded` 인 상태에서 독립적으로 실패할 수 있으므로
(`.../ViewModels/HomeViewModel.swift:201-209`) 실제로 도달 가능한 분기입니다.

레거시는 `SectionErrorCard` + 재시도를 렌더했고(`AppProduct/.../HomeView.swift:338-349`),
재시도 핸들러 `retryRecentNoticeSection()` 은 **`roles` 가 비어 있으면 프로필부터 다시 받고** 공지를 재조회했습니다
(`AppProduct/.../HomeView.swift:377-386`). 이 복구 경로가 통째로 없습니다.

### 1-5. ⛔ 홈 진입 시 프로필 저장(`saveProfileToStorage`)이 미이식 — 세션 중 권한 변경이 반영되지 않음

레거시 `HomeViewModel.saveProfileToStorage()` (`AppProduct/.../HomeViewModel.swift:109-148`) 는
홈을 열 때마다 `memberId`/`schoolId`/`gisuId`/`challengerId`/`chapterId`/`part`/`organizationType`/
`organizationId`/`memberRole`/`memberRoles`/`generationOrganizations`/`canAutoLogin` 을 갱신하고,
`UserSessionManager.updateRole` 호출 + `.memberProfileUpdated` 노티피케이션을 발행했습니다.

UMCApp 에서 이 동작은 **로그인 시점에만** 일어납니다
(`UMCApp/Features/Auth/Domain/Sources/UseCases/Implementations/SyncProfileStorageUseCase.swift:41-68`).

파급:

- 세션 도중 서버에서 역할·기수가 바뀌어도 앱이 모릅니다 (재로그인 전까지).
- `.memberProfileUpdated` 를 구독하는 **FCM 토큰 재동기화가 홈에서 발화하지 않습니다**
  (`UMCApp/UMCApp/Sources/AppDelegate.swift:66,149`).
- 파생 상태 `roles` 가 없어졌습니다 (레거시 `HomeViewModel.swift:28`). `HomeProfileResult` 는
  `memberId`/`seasonTypes`/`generations` 만 보유 (`UMCApp/.../Data/Sources/Repositories/HomeRepository.swift:53-57`).
- 공지 조회의 **`gisuId` 폴백 소실**: 레거시는 roles 에 기수가 없으면
  `UserDefaults[AppStorageKey.gisuId]` 로 폴백했지만(`AppProduct/.../HomeViewModel.swift:234-238`),
  UMCApp 은 `generations` 가 비면 빈 공지 목록을 반환합니다 (`UMCApp/.../HomeViewModel.swift:189-191`).

> 이 항목은 Home 단독 판단으로 처리하면 안 됩니다. Auth 의 `SyncProfileStorageUseCase` 를 재사용할지,
> Home 전용 경로를 되살릴지는 **소유권 결정이 선행**돼야 합니다 (§3 #J 참조).

---

## 2. P1 — UX·성능 열화 (동작은 하지만 레거시보다 나쁨)

| # | 항목 | 레거시 | UMCApp 현재 |
|---|---|---|---|
| 2-1 | 섹션별 재시도 스피너 | `.loading where isRetryingProfileSection / isRetryingRecentNoticeSection` (`AppProduct/.../HomeView.swift:36-37,141,171,338`) | `isRetrying: false` 하드코딩 (`HomeView.swift:139`) — 재시도해도 아무 피드백 없음 |
| 2-2 | 일정 아이콘 분류 게이트 | 보이는 일정이 전부 분류될 때까지 리스트를 막고 `TaskGroup` 병렬 분류 + stale 결과 가드 (`AppProduct/.../HomeView.swift:226-228,266-307`) | 게이트 없이 `.general` 폴백 → **아이콘 팝인**. 월 전체를 `for await` **순차** 분류 (`HomeViewModel.swift:142-144,168-178`) |
| 2-3 | 시맨틱 로딩 뷰 | `LoadingView(.home(.seasonLoading/.penaltyLoading/.recentNoticeLoading))` | 밋밋한 `ProgressView` 박스 (`HomeView.swift:280-287`). `LoadingView` 는 이미 있음 (`UMCApp/Core/UIComponents/Sources/Loading/LoadingView.swift:29`) |
| 2-4 | AI 자동완성 실패 표시 | 시트 안 `statusArea` 가 `.failed` 인라인 렌더 (`AppProduct/.../ScheduleRegistrationView.swift:863-877`) | `statusArea` 없음. 실패 시 `.idle` 로 되돌리고 전역 알럿에 위임 (`+AI.swift:48-53`) → **시트는 열린 채 이유 없이 멈춤** |
| 2-5 | AI 미지원 기기 안내 | `"이 기기에서는 Apple Intelligence를 사용할 수 없습니다."` (`AppProduct/.../+AI.swift:28-33`) | 조용히 `return` (`+AI.swift:37`) → **버튼을 눌러도 무반응** |
| 2-6 | 피커 토글 시 키보드 해제 | `KeyboardDismissOnPickerToggle` 이 10개 피커 + `isAllDay` 에서 `resignFirstResponder` (`AppProduct/.../ScheduleRegistrationView.swift:654-679`) | `.scrollDismissesKeyboard(.immediately)` 뿐. **제목/메모 포커스 상태로 날짜 피커를 열면 키보드가 피커를 가림** |
| 2-7 | 삭제 진행 중 표시 | 휴지통 → 빨간 `ProgressView` 로 교체 (`AppProduct/.../ScheduleDetailView.swift:131-133`) | 액션 목록을 빈 배열로 반환 (`UMCApp/.../ScheduleDetailView.swift:121`) → **메뉴가 조용히 비어버림** |

**렌더링 성능 회귀 2건** (`Equatable` 소실):

- `SeasonCard` 가 `Equatable` 이 아님 (`UMCApp/.../Components/SeasonCard.swift:13`).
  레거시는 `.equatable()` 적용 (`AppProduct/.../HomeView.swift:160`) → 프로필 tick 마다 HStack 재렌더.
- 등록 화면 제목 필드가 `TitleView: View, Equatable` 래퍼를 잃고 raw `TextField` 로 인라인됨
  (`UMCApp/.../ScheduleRegistrationView.swift:136-146` ↔ 레거시 `:342-364`, `.equatable()` at `:299`).
  **키 입력마다 폼 전체 행이 diff** 됩니다. `MemoEditor` 는 래퍼를 유지 중(`:452`)이라 대조적입니다.

**의도된 미이식 (조치 불필요, 기록용):**

- 상세 화면 **역지오코딩(도로명 주소)** — 레거시 `fetchRoadAddress` + 주소 행 + 편집 화면 prefill
  (`AppProduct/.../ScheduleDetailViewModel.swift:56-81`, `View:82-89,163,389-393`).
  UMCApp 은 좌표를 바로 Maps 로 넘깁니다 (`ScheduleDetailViewModel.swift:106-115`). 의도 명시됨(`View:18`).
- 편집 화면 표시가 `fullScreenCover` → `sheet` 로 변경 (레거시 `:47-58` ↔ UMCApp `:89-98`).
- 디버그 권한 오버라이드 `--schedule-force-permission` 미이식 (레거시 VM `:110-117`).
  이 플래그에 의존하는 UI 테스트가 있다면 훅이 없습니다.

---

## 3. P2 — 규약 위반 · 부채

### 3-1. 절대 규칙 #2 위반 (서버 정수 `String` 통일)

| 위치 | 위반 | 조치 |
|---|---|---|
| `UMCApp/Features/Home/Domain/Sources/Models/Schedule/ScheduleCapabilities.swift:25` | `maxParticipantCount: Int` (Domain) | `String` 으로. 비교 시점에만 `Int(...)` |
| `UMCApp/Features/Home/Data/Sources/DTOs/Response/ScheduleCapabilitiesDTO.swift:26` | `maxParticipantCount: Int` (Response DTO) | 동일. 디코딩은 이미 `decodeIntFlexibleIfPresent`(`:44`)라 타입만 바꾸면 됨 |
| `UMCApp/Features/Home/Domain/Sources/Models/PointLog.swift:18` | `point: Int` | **버그 동반**: 원본이 `Double`(`UMCApp/Core/Domain/Sources/Member/ProfileChallengerPoint.swift:15`)인데 `Int(point.point)` 로 절삭 (`.../Extensions/ProfileChallengerRecord+HomeMapping.swift:50`) → **`-0.5` 점이 `0` 이 됨** |

`ScheduleCapabilities` 는 **소비처가 0인 지금이 타입을 바꾸기 가장 싼 시점**입니다 (§1-2 결선 전에 처리).

> 참고 — `UMCApp/Features/Home/Data/Sources/GenerationMappingRecord.swift:24,27` 의
> `gisuId`/`gen` 은 `Int` 이지만 SwiftData 로컬 레코드이고 경계에서 변환됩니다
> (`ChallengerGenRepository.swift:41-42`). 서버 응답 타입이 아니므로 위반 아님.

### 3-2. 절대 규칙 #3 — **위반 없음**

`UMCApp/Features/Home/Data/Sources/DTOs/Response/` 6개 파일 전부 custom `init(from:)` + `encode(to:)` 보유.
`ScheduleRepository.swift:236` 의 `decode(Int.self)` 는 `FlexibleIdentifier` 의 single-value 폴백으로 정당(`:217-221` 에 문서화).

### 3-3. 절대 규칙 #5 위반 — Preview 11개가 `#if DEBUG` 미가드

```
Components/PenaltyCard.swift:350              (HomeGeneration 3 + PointLog 4 — 최대 픽스처)
Components/RecentNoticeCard.swift:109         Components/ScheduleListCard.swift:80
Components/AttendancePolicyDisplaySection.swift:176
Components/SeasonCard.swift:91                Components/ScheduleCard.swift:85
Components/Calendar/CalendarGridCard.swift:140   CalendarHorizonCard.swift:103
Components/Calendar/ScheduleHeader.swift:157     DatePill.swift:91   DateCell.swift:68
```

가드가 제대로 된 대조군: `NoticeAlarmCard.swift:79`, `HomeView.swift:324`,
`ScheduleDetailView.swift:367`, `ScheduleRegistrationView.swift:620`, `NoticeAlarmView.swift:101`, `TagListView.swift:103`.

> 같은 위반 유형이 Notice·Activity·Core 에도 있습니다. **Home 한정 패스로는 해결되지 않으므로**
> 전역 스윕은 별도 이슈로 분리합니다.

### 3-4. StubSession 에 `ScheduleCapabilitiesRepositoryProtocol` 미등록

`UMCApp/UMCApp/Sources/Debug/StubSession/DIContainer+StubSession.swift:25-52` 는 9개 Repository 를
오버라이드하지만 `ScheduleCapabilitiesRepositoryProtocol` 이 빠져 있습니다.
**스텁 세션인데 이 resolve 만 실제 네트워크를 탑니다.**

지금은 소비처가 0이라(§1-2) 무해하지만, **capabilities 를 결선하는 순간 터집니다.**
§1-2 와 반드시 같은 PR 에 넣으세요.

### 3-5. 테스트 공백

**테스트 0건:**

| 대상 | 비고 |
|---|---|
| `ScheduleRegistrationViewModel` (553줄) + `+AI` (168줄) + `ScheduleDraft` | **Home 최대 미검증 표면**. `*RegistrationViewModelTests` 는 Activity 것만 존재 |
| `UpdateScheduleUseCase` | `ScheduleUpdatePipelineTests.swift:31` 은 DTO/Repository 계층만 검증 |
| `GenerateScheduleUseCase` / `FetchScheduleCapabilitiesUseCase` / `ScheduleCapabilitiesRepository` | `ScheduleCapabilitiesDTOTests.swift:16` 은 DTO 만 |
| `DeleteScheduleUseCase` / `ForceDeleteScheduleUseCase` | `ScheduleDetailViewModelTests` 에서 목으로 간접 커버만 |
| `FetchSchedulesUseCase` / `FetchScheduleDetailUseCase` | 간접 커버만 |

**커버된 것:** `NoticeHistoryData`, `ClassifyNoticeUseCase`, `ClassifyScheduleUseCase`,
`FetchHomeProfileUseCase`, `RegisterFCMTokenUseCase`, `ChallengerGenRepository`, `HomeRepository`,
`ScheduleCapabilitiesDTO`, `ScheduleClassifierRepository`, `ScheduleDetailDTO`,
`ScheduleRepository`(update/delete 파이프라인), `HomeViewModel`, `ScheduleDetailViewModel`.

### 3-6. `docs/claude/tuist-file-mapping.md` stale 행

범례(`:26-33`)상 **주석 없는 행 = "정상 이식 대상"** 인데, 아래 행들은 이미 다른 모듈로 이관됐거나 dead 입니다.

| 유형 | 행 |
|---|---|
| 실제 목적지가 Activity/Core/Notice (행에는 Home 으로 표기) | 403, 404, 405, 406, 412, 422, 427, 435, 450, 475, 478, 480, 488, 489, 490, 492, 498, 513, 517, 518, 519 |
| Home 내 레이어 오기 (Presentation 표기 → 실제 Domain) | 499 (`NoticeAlarmType`), 505 (`SeasonType`) |
| dead/superseded 마커 누락 | 443 (`ChallengerRole`→CoreDomain `ProfileRole`), 445 (`RecentNoticeData`→`NoticeItemModel`), 501, 502, 503, 506 (`HomeUseCaseProvider`→`DIContainer+Home`) |
| 개명 주석 필요 (108/116 행 선례) | 444 (`GenerationData`→`HomeGeneration`), 457 (`ScheduleRegistrationData`→`ScheduleCreationRequest`), 521 (`Registration/ScheduleDetailView`→`Views/ScheduleDetailView.swift`) |

**dead 목록 추가분** (초판 12개에 더해, 레거시 내 참조도 0으로 확인):
`Presentation/Enum/RecentCategory.swift`, `Presentation/Enum/ScheduleCategory.swift`,
`Presentation/Enum/ScheduleGenerationType.swift`, `Presentation/Provider/HomeUseCaseProvider.swift`.

### 3-7. 그 밖에 확인된 것

- `ScheduleAttendancePolicyDTO.swift` / `ScheduleLocationDTO.swift` 가
  `Features/Home/Data/Sources/DTOs/Response/` 와 `Features/Activity/Data/Sources/DTOs/` 에 **중복 존재**.
  일정 도메인 소유는 Home 으로 확정됐으므로(`fb2cb915`) Activity 쪽 정리 대상 — **추정**(소비처 미확인).
- 하단 액세서리(`tabViewBottomAccessory`)는 여전히 없습니다. 현재 등록 진입점은
  `HomeView` 툴바 `+` (`HomeView.swift:99` → `HomeFeatureView.swift:53` → `RootTabView.swift:106`)이며
  **스스로 임시라고 표기**돼 있습니다(`HomeView.swift:98`). 5개 탭 전체 액세서리 정책이 필요한 App 셸 작업이므로
  초판 판단(별도 이슈) 유지.
- `ScheduleRegistrationViewModel` 은 레거시보다 **나은 부분도 있습니다**: `EditFormSnapshot` 에 출석 4필드 추가
  (`:528-531`, 레거시 `:649-662` 는 누락), `canSubmit` 에 `attendancePolicyErrorMessage == nil` 추가(`:120`).
  `+AI` 는 토큰 사용량을 기록만 하는 레거시와 달리 복원·표시까지 합니다(`+AI.swift:64-80`, `View:604-611`).
- 출석 정책 검증 규칙 5종(`checkInStart<onTimeEnd`, `onTimeEnd<lateEnd`, `checkInStart<시작`,
  `lateEnd<=종료`(=`lateExceedsEnd`), 종일/비출석 시 스킵)은 **전부 이식 완료**
  (`ScheduleRegistrationViewModel.swift:401-420`).

---

## 4. 이슈 분할안

```
   ┌───────────────────────────────────────────────┐
   │ #J 참여자 선택 결선 (P0)  ★ 첫 착수           │
   │   ├ ActivityPresentation 4종 public 승격      │
   │   └ Home Project.swift 의존 추가              │
   └───────────────────┬───────────────────────────┘
                       ▼
   ┌───────────────────────────────────────────────┐
   │ #K capabilities 결선 (P0) — 참여자 상한·출석  │
   │   + 규칙 #2 교정 + StubSession 등록 (동일 PR) │
   └───────────────────────────────────────────────┘

   ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
   │ #L 시작된 일정   │ │ #M 홈 섹션 에러· │ │ #N 프로필 저장   │
   │    편집 차단     │ │    재시도 복원   │ │    소유권 결정   │
   └──────────────────┘ └──────────────────┘ └──────────────────┘
              (셋 다 독립 · P0)

   ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
   │ #O UX 열화 7건   │ │ #P 등록 VM 테스트│ │ #Q 매핑표 동기화 │
   └──────────────────┘ └──────────────────┘ └──────────────────┘
              (P1)              (P2)              (P2)
```

### ★ #J — `✨ Feature: 홈 일정 등록 참여자 선택 결선` **(첫 착수)**

- **선행**: 없음
- **범위**
  - `UMCApp/Features/Activity/Presentation/Sources/Components/Challenger/{SearchChallengerView,SelectedChallengerView,ChallengerFormView,ChallengerSearchCard}.swift` — 타입 + `init` `public` 승격
  - `UMCApp/Features/Home/Project.swift` — `presentationExtraDependencies` 에 `ActivityPresentation`·`ActivityDomain` 추가
  - `ScheduleRegistrationViewModel` — `searchChallengersUseCase` 주입, 참여자 상태, `sanitizedParticipantMemberIds()`(본인 강제 포함), 편집 prefill(`fetchPrefillParticipants` 상당), `EditFormSnapshot` 에 `participantMemberIds` 추가
  - `ScheduleRegistrationView` — 참여자 섹션 + 시트
  - 생성 `participantMemberIds: []` → 실제 값, 수정 `nil` → 변경 시에만 전송
- **적용 절대 규칙**: #2(`ChallengerInfo.memberId` 는 이미 `String`), #4 `public`, #7
- **검수 기준**: 생성된 일정에 **작성자 본인이 항상 포함**. 편집 진입 시 기존 참여자 prefill. 참여자만 바꿔도 저장 버튼 활성화.
- **순환 의존 확인 필수** — `Features/Activity/Project.swift` 가 Home 을 참조하지 않는지 `tuist generate` 로 검증
- **크기**: **M**
- **왜 첫 번째인가**: 유일하게 **잘못된 데이터를 서버에 쓰고 있는** 항목입니다. #K 의 참여자 상한도 여기에 종속됩니다.

### #K — `♻️ Refactor: ScheduleCapabilities 결선 + maxParticipantCount String 교정`

- **선행**: #J
- **범위**
  - `ScheduleCapabilities.swift:25` · `ScheduleCapabilitiesDTO.swift:26` — `Int` → `String` (절대 규칙 #2)
  - `ScheduleRegistrationViewModel` — `loadCapabilities()` 추가, `.task` 호출, 출석 토글 게이트, 참여자 상한 경고 + 등록 차단
  - `ScheduleRegistrationView:183-187` — stale 주석 제거, 토글 조건부 노출
  - `DIContainer+StubSession.swift` — `ScheduleCapabilitiesRepositoryProtocol` 등록 **(누락 시 스텁 세션이 실네트워크를 탐)**
  - `FetchScheduleCapabilitiesUseCase` 테스트 신규
- **검수 기준**: `maxParticipantCount` 가 `"30"`·`30` 어느 쪽이든 `"30"` 으로 디코딩. 권한 없으면 출석 토글 비노출. 상한 초과 시 인라인 경고 + 등록 차단. 스텁 세션에서 네트워크 미발생.
- **크기**: **M**

### #L — `🐛 Fix: 이미 시작된 일정 편집 진입 사전 차단`

- **선행**: 없음
- **범위**: `ScheduleDetailView` 가 `viewModel.isScheduleStarted`(`:47`)를 읽어 편집 메뉴 비활성 + a11y label/hint, 상세 상단 잠금 배너 복원, 삭제 진행 중 `ProgressView` 표시(§2-7)
- **검수 기준**: 시작된 일정에서 편집 메뉴 비활성 + 사유 표시. 저장 단계 `SCHEDULE-0028` 는 최후 방어선으로 유지.
- **크기**: **S**

### #M — `🐛 Fix: 홈 섹션 에러 표시·재시도 복원`

- **선행**: 없음
- **범위**: `HomeView.swift:213-214` 의 `EmptyView` → `SectionErrorCard` + 재시도,
  `retryRecentNoticeSection()`(roles 비면 프로필 재조회 후 공지) 이식,
  `isRetrying` 실제 상태 결선(`:139`), `LoadingView(.home(...))` 로 교체(`:280-287`)
- **검수 기준**: 공지만 실패해도 헤더 유지 + 에러 + 재시도. 재시도 중 스피너 노출.
- **크기**: **S**

### #N — `♻️ Refactor: 홈 진입 프로필 저장 경로 소유권 확정`

- **선행**: 없음 (단 **설계 결정 선행 필요**)
- **결정 사항**: Auth 의 `SyncProfileStorageUseCase`(`:41-68`)를 Home 에서 재사용할지, Home 전용 경로를 되살릴지
- **범위**: 결정에 따라 — 홈 로드 시 프로필 저장 + `UserSessionManager.updateRole` + `.memberProfileUpdated` 발행, 공지 `gisuId` 폴백 복원(`HomeViewModel.swift:189-191`)
- **검수 기준**: 세션 중 역할·기수 변경이 홈 재진입만으로 반영. FCM 재동기화 발화 확인.
- **크기**: **M**
- **비고**: Auth 와 소유권이 겹치므로 Home 단독 판단 금지. `ios-architect` 선행 검토 권장.

### #O — `🐛 Fix: 홈·등록 화면 UX 열화 7건 일괄 복구`

- **선행**: 없음
- **범위**: §2 표의 2-2(분류 게이트 + `TaskGroup` 병렬화), 2-4·2-5(AI 실패/미지원 안내), 2-6(피커 키보드 해제), `SeasonCard`·제목 필드 `Equatable` 복원
- **크기**: **M**
- **비고**: 2-2 는 성능 회귀 성격이라 단독 분리해도 됩니다.

### #P — `✅ Test: 일정 등록 ViewModel + 쓰기 UseCase 테스트`

- **선행**: #J, #K (시그니처 확정 후)
- **범위**: `ScheduleRegistrationViewModelTests`(검증 규칙 5종 · 편집 변경 감지 · 참여자 상한 · `SCHEDULE-0028`),
  `UpdateScheduleUseCase` / `GenerateScheduleUseCase` / `DeleteScheduleUseCase` / `ForceDeleteScheduleUseCase` 직접 테스트
- **크기**: **M**

### #Q — `📝 Docs: tuist-file-mapping.md Home 구간 동기화`

- **선행**: 없음
- **범위**: §3-6 표의 행 갱신 + dead 목록 4건 추가
- **크기**: **XS**

### #R — `🔧 Chore: Preview #if DEBUG 가드 전역 스윕`

- **선행**: 없음
- **범위**: §3-3 의 Home 11건 + Notice·Activity·Core 동일 위반
- **크기**: **S**
- **비고**: Home 이슈가 아니라 전역 이슈. 별도 담당 가능.

---

## 5. 리스크

| 지점 | 위험 | 완화 |
|---|---|---|
| `Features/Home/Project.swift` 에 `ActivityPresentation` 추가 (#J) | **순환 의존** | `Features/Activity/Project.swift` 가 Home 을 참조하지 않는지 확인 후 `tuist generate` 검증 |
| Challenger 컴포넌트 `public` 승격 (#J) | 낮음 — 접근 제어자만 변경 | Activity 소비처 회귀 없음 |
| `ScheduleCapabilities` `Int`→`String` (#K) | 낮음 — **현재 소비처 0** | 지금이 가장 싼 시점. 결선 후에 하면 호출부까지 번짐 |
| `DIContainer+StubSession` 누락 (#K) | **높음** — 결선 즉시 스텁 세션이 실네트워크 | #K 와 동일 PR 필수 |
| `PointLog.point` `Int` 절삭 (§3-1) | 중간 — 소수점 벌점이 조용히 0 | `HomeGeneration` 합산 로직 동반 확인 |
| 프로필 저장 경로 (#N) | **높음** — Auth 와 소유권 중첩 | 설계 결정 선행. 중복 저장 시 `.memberProfileUpdated` 중복 발행 주의 |
| 분류 게이트 복원 (#O 2-2) | 중간 — 첫 렌더 지연 증가 | 레거시처럼 **보이는 범위만** 게이트. 월 전체 게이트 금지 |

## 6. 조사 방법 · 한계

- 판정 기준은 파일명이 아니라 **역할과 소비자**입니다. `superseded` = UMCApp 의 다른 타입이 같은 역할 수행,
  `dead` = 레거시 안에서도 참조 0.
- §1-1·1-2·1-3 의 핵심 주장(참여자 하드코딩, capabilities 소비처 0, `isScheduleStarted` 미사용,
  Challenger `internal`, Project.swift 의존 부재, StubSession 미등록)은 **직접 grep/read 로 재확인**했습니다.
- §2 표와 §3-6 의 행 번호는 전문(全文) 대조 결과이며 **개별 재확인은 하지 않았습니다**.
  착수 전 해당 파일을 다시 열어 확인하세요.
- `ScheduleAttendancePolicyDTO`/`ScheduleLocationDTO` 중복(§3-7)은 소비처를 확인하지 않은 **추정**입니다.
