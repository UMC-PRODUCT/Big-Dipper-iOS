# watchOS Complication (UMCWatchComplication)

> 워치페이스 accessory 위젯 3종(#1215)의 데이터 흐름·모듈 배치·App Group·갱신 정책 레퍼런스.
> 워치 토큰·Glass 절제 규칙은 `docs/claude/watch-design-system.md`, WC 통신 계약은 `UMCApp/Core/WatchConnectivity` 소스 주석 참고.

- 작성자: 제옹(euijjang97)
- 기준 코드:
  - `UMCApp/Core/WatchConnectivity/Sources/Complication/ComplicationSnapshot.swift`
  - `UMCApp/Core/WatchConnectivity/Sources/Complication/ComplicationStore.swift`
  - `UMCApp/Core/WatchConnectivity/Sources/WatchSessionCoordinator.swift`
  - `UMCApp/UMCWatchComplication/Project.swift` · `Sources/` 6개 파일
  - `UMCApp/UMCWatchApp/Sources/ComplicationSyncModifier.swift`
  - `UMCApp/Tuist/ProjectDescriptionHelpers/Project+WidgetExtension.swift`
  - `UMCApp/Core/WatchConnectivity/Tests/ComplicationSnapshotTests.swift` · `ComplicationStoreTests.swift`

## 1) 한눈에 — Complication 3종

전부 `StaticConfiguration` + 단일 공유 프로바이더(§7)이고, 지원 family 는 셋 다 동일하다:
`.accessoryCircular` · `.accessoryRectangular` · `.accessoryInline`.

| kind | 표시 이름 | 그리는 것 | 파일 |
|------|-----------|-----------|------|
| `UMCNextSession` | 다음 세션 | 가장 가까운 세션까지 남은 시간 — circular 는 카운트다운 링, rectangular 는 세션명+상대시각 | `Sources/NextSessionComplication.swift` |
| `UMCAttendanceStatus` | 출석 상태 | 다음 세션의 출석 상태 (심볼+라벨+링, §5) | `Sources/AttendanceStatusComplication.swift` |
| `UMCPingCount` | 미확인 공지 | 미확인 The Ping 개수 (`99+` 절단) + `generatedAt` 신선도 캡션 | `Sources/PingCountComplication.swift` |

- 로그아웃(또는 최초 동기화 전) 상태는 3종 모두 공통 뷰 `ComplicationSignedOutView` 로 「iPhone 로그인 필요」를 그린다 — 워치는 스스로 로그인할 수 없으므로 같은 문구여야 사용자가 조치처를 한 번에 안다 (`Sources/ComplicationStyle.swift:46-49`).
- 3종 모두 `.privacySensitive()` — 손목 프라이버시 모드에서 값이 가려진다 (예: `NextSessionComplication.swift:55-57`).

## 2) 데이터 흐름 — 워치는 서버를 폴링하지 않는다

```
운영진 승인/공지 → 서버 → 푸시 → iPhone 앱
    → WatchSessionCoordinator.publishSessionState(_:)          // WC updateApplicationContext
    → 워치 앱 didReceiveApplicationContext → receivedState 갱신
    → ComplicationSyncModifier (onChange of receivedState)
    → ComplicationSnapshot(state:) 파생 (순수 함수)
    → ComplicationStore.save → App Group UserDefaults
    → WidgetCenter.reloadAllTimelines() → 워치페이스
```

- **워치·익스텐션 어디에도 네트워크 코드가 없다.** 최신값의 유일한 통로는 iPhone 이 `updateApplicationContext` 로 밀어 넣는 `WatchSessionState` 다 (`WatchSessionCoordinator.swift:124-134`, `Models/WatchSessionState.swift:12-16`).
- 워치 앱은 `didReceiveApplicationContext` 에서 `receivedState` 를 갱신하고 (`WatchSessionCoordinator.swift:302-315`), `ComplicationSyncModifier` 가 이를 관찰해 스냅샷을 저장한다 (`UMCWatchApp/Sources/ComplicationSyncModifier.swift:26-32`). 진입점은 앱 루트의 `.syncsComplication(with:)` 한 줄이다 (`UMCWatchApp/Sources/UMCWatchApp.swift:20-26`).
- `onChange(…, initial: true)` 인 이유는 **콜드런치 시딩**이다 — WC 활성화 시점에 이미 도착해 있던 컨텍스트에는 델리게이트 콜백이 다시 오지 않아(활성화 완료 시 `receivedApplicationContext` 로 시딩됨, `WatchSessionCoordinator.swift:243-253`), `initial` 이 없으면 첫 값이 그대로 누락된다 (`ComplicationSyncModifier.swift:16-17`).
- `WatchSessionState` 를 그대로 저장하지 않고 `ComplicationSnapshot` 으로 줄이는 이유: 워치페이스는 「다음 하나」와 「개수」만 그리는데, 타임라인 리프레시마다 목록 전체를 디코딩하면 매 갱신에 낭비가 붙는다 (`ComplicationSnapshot.swift:13-16`).

### 2-1) `ComplicationSnapshot` 파생 규칙

`init(state:now:)` 는 순수 함수라 테스트가 규칙을 잠근다 (`ComplicationSnapshot.swift:48-57`, §9):

| 필드 | 규칙 | 근거 위치 |
|------|------|-----------|
| `nextSession` | `endsAt > now` 인 세션 중 `startsAt` 최소 (동률이면 `scheduleId` 사전순). 진행 중 세션은 정렬만으로 자연히 우선 | `ComplicationSnapshot.swift:76-89` |
| `attendance` | 서버 원본 문자열 매핑 우선 → 없거나 모르는 값이면 출석 창 폴백 (§5) | `ComplicationSnapshot.swift:91-103` |
| `unreadPingCount` | `notices` 중 `!isRead` 개수. 상한 없음 — `99+` 절단은 뷰의 책임 | `ComplicationSnapshot.swift:26-27, 54` |
| `generatedAt` | 원본 스냅샷 생성 시각 그대로 — 「N분 전 기준」 신선도 표시용 | `ComplicationSnapshot.swift:28-29`, `PingCountComplication.swift:101-104` |

`scheduleId` 는 서버 정수를 `String` 으로 보존한다 (절대 규칙 #2, `ComplicationSnapshot.swift:124-125`).

## 3) 모듈·타겟 배치

### 3-1) 왜 새 Core 모듈이 아니라 `CoreWatchConnectivity` 안인가

`ComplicationSnapshot`·`ComplicationStore` 는 `Core/WatchConnectivity/Sources/Complication/` 에 있다.

- 파생 로직의 입력이 `WatchSessionState` 라 **WC 계약의 연장**이다. 모듈을 가르면 워치 계약이 바뀔 때마다 두 모듈이 lockstep 으로 움직여야 한다.
- 익스텐션 타겟은 유닛 테스트에서 import 할 수 없다 — 파생·타임라인 규칙을 익스텐션에 두면 테스트 불가가 된다 (`ComplicationSnapshot.swift:263-266`). Core 에 두면 기존 `CoreWatchConnectivityTests` 스킴이 그대로 잠근다 (§9).
- 대가로 `CoreWatchConnectivity` 가 `WidgetKit` SDK 를 문다 — `ComplicationStore.save` 가 저장 직후 타임라인을 리로드하기 위해서다. 저장과 리로드를 갈라 두면 호출자가 리로드를 빠뜨려 값이 조용히 낡는다 (`Core/WatchConnectivity/Project.swift:4-5, 13`).

### 3-2) 익스텐션 타겟 `UMCWatchComplication`

- **번들 ID 는 반드시 워치 앱 번들 ID(`com.umc.product.watchkitapp`)를 prefix 로 가진다** → `com.umc.product.watchkitapp.complication`. 어긋나면 워치 앱이 익스텐션을 임베드하지 못하고 업로드가 거부된다 (`UMCWatchComplication/Project.swift:4-8`).
- 임베드는 Tuist 가 처리한다 — `UMCWatchApp` 이 `.project(target: "UMCWatchComplication", …)` 을 걸면 워치 앱 PlugIns 에 자동 임베드된다 (`UMCWatchApp/Project.swift:4, 12`). 워크스페이스에도 명시 포함 (`UMCApp/Workspace.swift:11`).
- 매니페스트는 iOS 위젯(`UMCAppWidget`)과 같은 `widgetExtensionProject` 헬퍼를 쓴다. 헬퍼를 복제하지 않고 `destinations`/`deploymentTargets` 파라미터를 추가한 이유: 익스텐션 Info.plist 의 함정 — `CFBundleDisplayName` 누락 시 ITMS-90360 거부, `CFBundleVersion` 호스트 불일치 시 업로드 거부, `NSExtensionPointIdentifier` — 이 **플랫폼과 무관하게 동일**해서, 두 벌로 가르면 이 지식이 한쪽만 고쳐지는 드리프트가 생긴다 (`Tuist/ProjectDescriptionHelpers/Project+WidgetExtension.swift:16-47`). watchOS 는 `destinations: [.appleWatch]` + `deploymentTargets: .watchOS("26.4")` 만 넘긴다 (`UMCWatchComplication/Project.swift:9-10`).

## 4) App Group — `group.com.umc.product.watch`

워치 앱(쓰기)과 익스텐션(읽기)은 프로세스가 달라 App Group `UserDefaults` 로 스냅샷을 공유한다 (`ComplicationStore.swift:25, 33-35`).

- **iOS 위젯의 `group.com.umc.product.widget` 을 재사용할 수 없다** — App Group 컨테이너는 iPhone 과 워치가 공유하지 않는다. 같은 식별자를 양쪽에 등록해도 물리적으로 다른 컨테이너라, 워치 전용 그룹을 따로 두는 편이 「공유되는 것처럼 보이는」 오해를 막는다 (`ComplicationStore.swift:14-16`).
- 식별자는 **세 곳이 정확히 일치**해야 한다: `ComplicationStore.appGroupIdentifier`, `UMCWatchApp/UMCWatchApp.entitlements`, `UMCWatchComplication/UMCWatchComplication.entitlements`. 어긋나면 저장은 성공한 것처럼 보이는데 익스텐션이 읽는 컨테이너가 달라 워치페이스가 영원히 비어 있다 (`ComplicationStore.swift:23-25`).

> ⚠️ **App Group 은 Apple Developer 포털 등록이 필요한 사람 작업이다.** `group.com.umc.product.watch` 를 포털에 등록하고 워치 앱·익스텐션 프로비저닝에 포함해야 한다. 미등록 상태에서는 `UserDefaults(suiteName:)` 이 nil 을 내고, `load()`/`save()` 는 guard 로 조용히 빠져나간다 (`ComplicationStore.swift:39-58`) — **크래시도 에러도 없이** 워치페이스만 「iPhone 로그인 필요」에 고정된다.

## 5) 출석 상태 매핑

서버 `AttendanceStatus` 원본 문자열(`WatchSchedule.attendanceStatus`, 절대 규칙 #2 로 String 보존)을 `ComplicationAttendanceState.from(rawStatus:)` 가 표시 상태로 바꾼다 (`ComplicationSnapshot.swift:232-241`). 색 토큰은 익스텐션 쪽 `fullColorTint` 다 (`UMCWatchComplication/Sources/ComplicationStyle.swift:21-30`).

| 서버 원본 | 상태 | SF Symbol | 라벨 | 링 | `.fullColor` 색 |
|-----------|------|-----------|------|:--:|-----------------|
| — (다음 세션 없음/출석 비필수) | `.none` | `calendar` | 예정 없음 | | `WatchColor.textSecondary` |
| — (창 열리기 전, 폴백) | `.upcoming` | `clock` | 출석 예정 | | `WatchColor.textSecondary` |
| — (창 열림, 폴백) | `.awaiting` | `location.circle` | 출석 가능 | | `WatchColor.brandPrimaryHighlight` |
| `PENDING` `PRESENT_PENDING` `LATE_PENDING` `EXCUSED_PENDING` | `.pending` | `hourglass` | 승인 대기 | ✅ | `WatchColor.statusPending` |
| `PRESENT` | `.present` | `checkmark.circle.fill` | 출석 | | `WatchColor.statusSuccess` |
| `LATE` | `.late` | `exclamationmark.circle.fill` | 지각 | | `WatchColor.statusWarning` |
| `EXCUSED` | `.excused` | `checkmark.shield.fill` | 공결 | | `WatchColor.statusPending` |
| `ABSENT` | `.absent` | `xmark.circle.fill` | 결석 | | `WatchColor.statusError` |

- **`EXCUSED` 를 `.present` 로 합치지 않는다** — 합치는 순간 공결 사용자가 볼 화면이 사라진다 (`ComplicationSnapshot.swift:229-241`, 테스트 `excusedStaysDistinct`).
- **모르는 문자열은 nil → 창 폴백**: `checkInStartAt` 이전 `.upcoming` → `lateEndAt` 이전 `.awaiting` → 이후 `.absent` (`ComplicationSnapshot.swift:105-115`). 창이 닫혔는데 상태가 없으면 결석이다 — 「알 수 없음」으로 두면 사용자가 조치할 시점을 놓친다. 서버가 미래에 상태를 추가해도 워치는 크래시 없이 폴백으로 동작한다 (테스트 `unknownStatusFallsBackToWindow`).
- `.pending/.present/.late/.excused/.absent` 는 `isServerConfirmed` — 시간이 흘러도 뒤집히지 않으므로 타임라인 경계 엔트리가 창 판정으로 덮어쓰지 않는다 (`ComplicationSnapshot.swift:219-225`, §7).

## 6) tinted(accented) 모드 — 색은 보조 채널이다

accented·vibrant 워치페이스에서는 **시스템이 색을 단색으로 치환**한다. 색으로만 구분하던 상태는 통째로 구별 불가가 된다. 그래서:

1. **모든 상태가 심볼(실루엣 상이)·라벨·링을 색과 병행한다** (`ComplicationSnapshot.swift:167-171`). 이 규칙은 `ComplicationSnapshotTests` 의 `stateChannelsAreDistinct`(8개 상태의 심볼·라벨 중복 금지, `Tests/ComplicationSnapshotTests.swift:259-268`)와 `pendingRingIsExclusive`(링은 `.pending` 전용, `:270-275`)가 잠근다.
2. 커스텀 색은 `.fullColor` 렌더링 모드에서만 적용한다 — `complicationTint(_:mode:)` 가 accented 에서 `.primary` 로 떨군다. 치환 대상 색을 커스텀으로 넘기면 강조 계층이 하나로 뭉개진다 (`ComplicationStyle.swift:35-42`).
3. `.pending`(승인 대기)과 `.excused`(공결)가 같은 중립색인 것은 의도다 — 스펙상 둘 다 「확정되지 않았거나 예외」 축이라 색으로 갈리지 않는다. 구분은 심볼과 **링(색이 아니라 형태라 accented 에서도 살아남는다)**이 맡는다 (`ComplicationStyle.swift:17-20`, `AttendanceStatusComplication.swift:45-46, 78-84`).
4. **Complication 에 Liquid Glass 를 쓸 수 없다** — accessory family 는 시스템이 렌더를 전담한다. 배경은 `AccessoryWidgetBackground()` 만 쓴다. `docs/claude/watch-design-system.md` §4 Glass 매트릭스의 금지 구역이다.

## 7) TimelineProvider 갱신 정책

3종은 `ComplicationProvider` **하나를 공유**한다 — 같은 스냅샷을 읽고 뷰만 다른데, 프로바이더를 복제하면 App Group 읽기를 세 벌 유지해야 하고 리로드 타이밍이 위젯마다 어긋난다 (`UMCWatchComplication/Sources/ComplicationProvider.swift:13-16`).

### 7-1) 엔트리 생성 — 상태가 실제로 바뀌는 시각만

`ComplicationTimeline.entries(from:now:)` (`ComplicationSnapshot.swift:279-287`):

- `now` 엔트리 1개 + **상태 전이 경계 시각**의 엔트리들. 경계 후보는 세션 `startsAt`/`endsAt` + 출석 창 3시각(`checkInStartAt`/`onTimeEndAt`/`lateEndAt`) 중 미래분, 오름차순 최대 6개 (`ComplicationSnapshot.swift:271-272, 289-296`). 워치 리프레시 예산이 유한해서 한 세션의 상태 전이를 덮는 최소치로 상한을 둔다.
- 경계 엔트리의 스냅샷은 `projected(at:)` 로 **출석 상태만** 재계산한다 — 미래 시점의 일정 목록·읽음 여부는 워치가 알 수 없고, 시간 경과만으로 확정적으로 바뀌는 값은 출석 창 판정뿐이다. 서버 확정 상태(`isServerConfirmed`)는 덮어쓰지 않는다 (`ComplicationSnapshot.swift:61-74`).
- **카운트다운 숫자로는 엔트리를 늘리지 않는다.** 분 단위 엔트리는 리프레시 예산을 태우므로, 링과 숫자는 `ProgressView(timerInterval:countsDown:)` + `Text(_, style: .timer)` / `Text(_, style: .relative)` 로 시스템이 스스로 갱신하게 맡긴다 (`NextSessionComplication.swift:79-90, 107`).

### 7-2) 리로드 정책

| 상황 | 정책 | 위치 |
|------|------|------|
| 경계 엔트리가 있음 | `.atEnd` — 마지막 경계를 지나면 재계산 | `ComplicationProvider.swift:71-73` |
| 경계 없음 (세션 없음 등) | `.after(now + 60분)` 폴백 | `ComplicationProvider.swift:21-23` |
| WC 로 새 스냅샷 도착 | `ComplicationStore.save` 가 즉시 `reloadAllTimelines()` — **이것이 갱신의 주 동력**이고 위 정책은 이 경로가 끊겼을 때의 안전망 | `ComplicationStore.swift:47-58` |

- 스토어가 비어 있으면(최초 동기화 전) `generatedAt = .distantPast` 인 `neverSyncedSnapshot` 을 그려 신선도 표시가 스스로 문제를 드러낸다 (`ComplicationProvider.swift:25-32`).
- 갤러리 표본(`gallerySnapshot`)은 `#if DEBUG` 로 가리지 않는다 — 릴리스 빌드의 워치페이스 갤러리도 이 값을 그린다 (`ComplicationProvider.swift:34-49`). 실사용자 데이터는 갤러리에 노출되지 않는다 (`context.isPreview` 분기, `:57-62`).

## 8) 체크리스트 — accessory 위젯을 하나 더 붙일 때

- [ ] `UMCWatchComplication/Sources/` 에 `Widget` + View 파일 추가 — kind 는 `UMC` prefix, `ComplicationProvider` 를 그대로 쓴다 (복제 금지, §7)
- [ ] `UMCWatchComplicationBundle.body` 에 한 줄 추가 (`Sources/UMCWatchComplicationBundle.swift:12-18`)
- [ ] 로그아웃 분기는 `ComplicationSignedOutView`, 콘텐츠에 `.privacySensitive()` + `.containerBackground(.clear, for: .widget)`
- [ ] 색은 `complicationTint(_:mode:)` 경유 — 상태를 색 단독으로 구분하지 않는다 (§6)
- [ ] 새 파생값이 필요하면 `ComplicationSnapshot` 에 필드를 추가하고 테스트를 함께 — 익스텐션 안에서 파생하지 않는다 (§3-1)

## 9) 테스트 — `make test SCHEME=CoreWatchConnectivity`

파생·저장 로직을 익스텐션이 아니라 Core 의 **순수 함수/주입 가능한 스토어**로 뽑아 놓은 이유가 이것이다. 워치페이스는 사용자가 앱을 열지 않고 보는 화면이라 잘못된 값을 정정할 기회가 없다 (`Tests/ComplicationSnapshotTests.swift:12-15`).

| 스위트 | 잠그는 것 |
|--------|-----------|
| `ComplicationSnapshotTests` | 다음 세션 선정(끝난 세션 제외·진행 중 우선·동률 규칙), 서버 상태 매핑(§5 표 전체), 창 폴백 3구간, 미확인 개수, 심볼·라벨 유일성, pending 링 배타성 |
| `ComplicationStoreTests` | 직렬화 왕복(ISO8601 — 소수점 이하 초는 왕복에서 잘린다, `:37-38`), 타임라인 경계 엔트리 순서·상한, 서버 확정 상태의 projection 생존 |

실제 App Group 은 서명된 앱에서만 열리므로 스토어 테스트는 임의 suite 이름을 주입한다 — 검증 대상은 컨테이너가 아니라 직렬화와 엔트리 규칙이다 (`Tests/ComplicationStoreTests.swift:12-15, 25-27`).

## 10) 남은 사람 작업

- [ ] **App Group 포털 등록**: `group.com.umc.product.watch` 를 Apple Developer 포털에 등록하고 워치 앱·익스텐션 App ID/프로비저닝에 포함 (§4 경고 참조 — 미등록 시 조용히 실패)
- [ ] **디자이너 tinted 목업 확정**: accented 모드 실기기 렌더 기준의 목업이 설계 스펙 §9(기획 레포)에 미해결로 남아 있다 — 확정되면 `fullColorTint`/링 두께 조정 가능성 있음
- [ ] **워치페이스 실배치 확인**: 실기기에서 3종을 워치페이스에 올려 accented/fullColor 양쪽, 갤러리 표본, 프라이버시 모드 가림을 확인
- [ ] **iPhone 쪽 퍼블리시 배선 (#1211)**: `publishSessionState(_:)` 는 API 만 존재하고 iOS 앱 쪽 호출부(푸시 수신·데이터 갱신 시점)는 아직 배선되지 않았다 — 배선 전까지 실기기 워치페이스는 「iPhone 로그인 필요」에 머무른다

## 11) 트러블슈팅

- 증상: 워치페이스가 「iPhone 로그인 필요」에 고정 / 영원히 비어 있음
  - 원인 1: App Group 미등록 또는 3곳 식별자 불일치 → `UserDefaults(suiteName:)` nil → `load()`/`save()` 가 guard 로 조용히 실패 (`ComplicationStore.swift:39-58`)
  - 원인 2: iPhone 이 `publishSessionState` 를 아직 호출하지 않음 (#1211, §10) — 스토어가 비어 `neverSyncedSnapshot`(`isSignedIn: false`)을 그린다 (`ComplicationProvider.swift:26-32`)
  - 해결: 포털 등록·entitlements 3곳 대조(§4) → iPhone 퍼블리시 경로 확인
- 증상: 워치 앱 값은 최신인데 워치페이스만 옛날 값
  - 원인: `ComplicationStore.save` 를 거치지 않고 스냅샷을 저장했거나(리로드 누락), 익스텐션이 다른 suite 를 읽는다 — 저장과 `reloadAllTimelines()` 를 묶어 둔 이유가 이것이다 (`ComplicationStore.swift:47-58`)
  - 해결: 쓰기는 항상 `ComplicationStore.shared.save(_:)` 경유
- 증상: 워치 콜드런치 직후 첫 스냅샷이 워치페이스에 반영 안 됨
  - 원인: `ComplicationSyncModifier` 의 `onChange(…, initial: true)` 가 빠졌다 — 활성화 전에 도착한 컨텍스트는 델리게이트 콜백이 다시 오지 않는다 (`ComplicationSyncModifier.swift:16-17, 28`)
  - 해결: `initial: true` 유지. 시딩 자체는 `activationDidCompleteWith` 가 담당한다 (`WatchSessionCoordinator.swift:243-253`)
- 증상: 서버가 새 출석 상태 문자열을 내려보낸 뒤 워치가 창 기반 상태(출석 가능/결석)를 그린다
  - 원인: `from(rawStatus:)` 가 모르는 값은 nil → 창 폴백 (`ComplicationSnapshot.swift:229-241`) — 크래시 대신 의도된 강등이다
  - 해결: 새 문자열을 `from(rawStatus:)` 와 §5 표·테스트에 추가
- 증상: accented 워치페이스에서 출석/지각/결석이 똑같아 보인다
  - 원인: 시스템 단색 치환은 정상이다. 상태 구분은 심볼·라벨·링이 담당한다 (§6) — 같아 보인다면 색 단독 표현이 섞였다는 뜻
  - 해결: `stateChannelsAreDistinct`/`pendingRingIsExclusive` 테스트가 통과하는지, 커스텀 색이 `complicationTint(_:mode:)` 를 우회하지 않는지 확인
- 증상: `saveLoadRoundtrip` 류 테스트가 `generatedAt` 불일치로 실패
  - 원인: 봉투 코덱이 ISO8601 이라 소수점 이하 초가 왕복에서 잘린다 (`Tests/ComplicationStoreTests.swift:37-38`)
  - 해결: 픽스처 시각을 초 단위로 딱 떨어지게 잡는다
