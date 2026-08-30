# 3D 명함 렌더러 — 회전·인터랙션·접근성

#1247 이 구현한 `BusinessCard3DView`/`BusinessCard3DScene` 의 동작 원리를 정리한 문서다.
후속 이슈(#1248 온디바이스 합성, #1249 명함첩 2D 스냅샷) 담당자가 이 렌더러를 어떻게
확장·재사용해야 하는지에 집중한다. 베이스 USDZ 템플릿의 앵커·머티리얼 슬롯 계약은
`docs/claude/business-card-3d-anchor-contract.md` 를 본다 — 이 문서에서 반복하지 않는다.
Phase 0 스파이크 실측치(첫 진입 지연, 스냅샷 비용)는 `docs/claude/business-card-3d-spike.md`.

- 작성자: euijjang97
- 기준 코드:
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCard3DView.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCard3DScene.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/CardRotation.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/CardInteractionPolicy.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/Card3DMetrics.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardTemplate.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Components/MyCard+CardFaceLabel.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Components/BusinessCardFaceView.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Tests/BusinessCard3DInteractionTests.swift`
  - `UMCApp/Core/Foundation/Sources/Enums/AppStorageKey.swift`

## 1) `makeEntity` seam — #1248 의 유일한 진입점

`BusinessCard3DView.init(...)` 은 카드 엔티티 생성을 클로저 하나로 받는다
(`BusinessCard3DView.swift:52-70`):

```swift
public init(
    card: MyCard,
    isFlipped: Bool = false,
    qrImage: CGImage? = nil,
    onFlip: (() -> Void)? = nil,
    onExchange: (() -> Void)? = nil,
    onQR: (() -> Void)? = nil,
    makeEntity: @escaping @MainActor @Sendable (MyCard) async throws -> Entity = { _ in
        try await BusinessCardTemplate.load()
    }
)
```

기본값은 `BusinessCardTemplate.load()` 한 줄 — 앵커·텍스트·머티리얼을 하나도 채우지 않은
베이스 템플릿을 그대로 반환한다. **#1248 이 할 일은 이 기본값 하나를 온디바이스 합성기 호출로
바꾸는 것뿐이다.** 예: `makeEntity: { card in try await CardEntityComposer.compose(card) }`.

새 프로토콜을 만들지 않는다 — 구현체가 하나뿐인 추상화라 클로저로 충분하고, `BusinessCard3DView.swift:49-51`
의 주석이 이미 그 판단 근거를 적어 뒀다("프리뷰·테스트도 여기로 주입한다"). 실제로 `#Preview("합성
실패 폴백")`(`BusinessCard3DView.swift:326-339`)이 이 seam 에 실패하는 클로저를 주입해 폴백
경로를 확인한다 — #1248 도 합성 실패 케이스를 같은 방식으로 프리뷰에서 검증하면 된다.

호출 경로는 `BusinessCard3DScene.load(card:isFlipped:makeEntity:)`(`BusinessCard3DScene.swift:65-72`)
로 이어진다. `makeEntity` 가 던지면 `BusinessCard3DView.loadSceneIfNeeded()`(`BusinessCard3DView.swift:261-274`)
가 잡아 `phase = .failed` 로 떨어뜨린다 — §3 참고.

## 2) 회전 상태를 SwiftUI 에 올리지 않는 이유

`BusinessCard3DScene` 은 `@MainActor final class` 이고 **의도적으로 `@Observable` 이 아니다**
(`BusinessCard3DScene.swift:13-23`). 자이로가 `Card3DMetrics.motionInterval`(1/60초, `Card3DMetrics.swift:45-47`)
간격으로 콜백을 주는데, 회전을 관측 프로퍼티에 담으면 SwiftUI `body` 가 초당 60회 재평가된다.

대신 `rotation: CardRotation`(비관측 저장 프로퍼티, `BusinessCard3DScene.swift:30`)을 들고
있다가 `setRotation(_:duration:timing:)`(`BusinessCard3DScene.swift:99-122`)에서 `cardEntity.transform.rotation`
에 직접 기입한다. `Entity` 는 참조 타입이고 SwiftUI 가 관측하지 않으므로 아무리 자주 써도
`body` 는 돌지 않는다. 같은 이유로 `RealityView` 의 `update:` 클로저도 쓰지 않는다 — 그건
SwiftUI 상태가 바뀔 때마다 호출되므로 관측 프로퍼티를 쓰는 것과 결국 같은 비용이다
(`BusinessCard3DScene.swift:18-19`). `RealityView`(`BusinessCard3DView.swift:118-120`)는
`make:` 클로저에서 `scene.attach(to:)` 를 한 번만 부른다.

절대 규칙 #1(`@Observable` 강제)과 충돌하지 않는 근거: 그 규칙이 막으려는 것은 Combine 시대의
관측 래퍼(`@StateObject`/`@ObservedObject`/`@Published`)이고, `BusinessCard3DScene` 은 그중
어느 것도 아니며 화면 상태를 들고 있는 ViewModel도 아니다 — 씬 그래프의 핸들이다
(`BusinessCard3DScene.swift:20-23`).

SwiftUI `@State` 로 남아 `body` 재평가를 일으키는 것은 `phase: CardScenePhase`(로딩/준비/실패,
초당 몇 회 수준)와 `isFlipped`/`isGyroEnabled` 토글뿐이다(`BusinessCard3DView.swift:37-40`).

#1248 이 유의할 점: 합성 결과 엔티티에 애니메이션 가능한 값(예: 하이라이트 셰이더 파라미터)을
추가하더라도 그 값을 SwiftUI 상태로 올리지 말고 같은 패턴 — `BusinessCard3DScene` 안에 비관측
프로퍼티로 두고 엔티티에 직접 기입 — 을 따른다.

## 3) 2D 폴백 규칙

`CardInteractionPolicy.renderMode(phase:dynamicTypeSize:)`(`CardInteractionPolicy.swift:71-77`)
이 3D/2D 분기의 유일한 판단 지점이다:

```swift
static func renderMode(
    phase: CardScenePhase,
    dynamicTypeSize: DynamicTypeSize
) -> CardRenderMode {
    guard !dynamicTypeSize.isAccessibilitySize else { return .twoDimensional }
    return phase == .ready ? .threeDimensional : .twoDimensional
}
```

2D 로 가는 세 경로:

- **접근성 글자 크기**(`dynamicTypeSize.isAccessibilitySize`) — 3D 텍스트는 메시라 Dynamic
  Type 에 반응하지 못한다. 이 경우 `loadSceneIfNeeded()`(`BusinessCard3DView.swift:262`)의
  guard 가 로드 자체를 시작하지 않는다.
- **`phase == .loading`** — 씬이 아직 로드되지 않은 초기 상태.
- **`phase == .failed`** — `makeEntity` 가 던졌을 때(§1).

세 경로 모두 폴백 뷰는 `BusinessCardFaceView` **그 자체**다(`BusinessCard3DView.swift:99-106`).
별도의 스켈레톤·스피너 뷰가 없다 — 시그니처를 `BusinessCardFaceView` 와 맞춰 뒀기 때문에
(`BusinessCard3DView.swift:15-16`) 폴백 분기 코드가 사실상 0줄이다.

실패는 사용자에게 알리지 않는다. 동작하는 2D 카드가 그대로 있고, "3D 로 못 그렸다"는 사용자가
할 수 있는 일이 없는 정보이기 때문이다(`CardInteractionPolicy.swift:68-70`). 대신 개발자용
로그만 남긴다(`BusinessCard3DView.swift:259-274`):

```swift
private let logger = Logger(
    subsystem: "dev.umc.feature.businesscard",
    category: "BusinessCard3D"
)
```

성공 시 `logger.info("3D 카드 로드 \(elapsed)ms")`, 실패 시 `logger.error("3D 카드 로드 실패,
2D 로 폴백: \(error.localizedDescription)")`. 실기기 첫 로드 지연은 Console.app 에서 이
로그 한 줄로 읽는다 — 별도 `OSSignposter` 계측 하네스는 만들지 않았다
(`BusinessCard3DView.swift:293-294`).

`.task(id: dynamicTypeSize.isAccessibilitySize)`(`BusinessCard3DView.swift:78`)로 감싸 둬서,
접근성 글자 크기로 넘어갔다 돌아오면 `phase` 가 그대로 `.loading` 이라도 로드를 다시 시도한다.

## 4) 접근성 정책

### Reduce Motion

- **플립 애니메이션**: `CardInteractionPolicy.flipDuration(reduceMotion:)`(`CardInteractionPolicy.swift:35-37`)
  이 Reduce Motion 이면 `0` 을 돌려줘 즉시 전환한다.
- **드래그 복귀는 예외** — Reduce Motion 이 막는 것은 사용자가 만들지 않은 자율 모션이고,
  드래그는 손가락이 직접 만드는 1:1 조작이라 그대로 애니메이션한다(`CardInteractionPolicy.swift:33-34`).
- **자이로**: `shouldRunGyro(...)`(`CardInteractionPolicy.swift:48-60`)가 Reduce Motion 이면
  무조건 `false` — 콜백 자체를 켜지 않아 배터리도 같이 아낀다.

### VoiceOver

- `shouldRunGyro` 가 `isVoiceOverRunning` 이면 자이로를 멈춘다 — 화면을 안 보는 사용자에게
  회전은 순수 소모이고, 탐색 중 카드가 혼자 움직이면 포커스 맥락이 흐려진다
  (`CardInteractionPolicy.swift:44-45`).
- `RealityView` 는 VoiceOver 에 아무것도 주지 않으므로 `cardSurface`(`BusinessCard3DView.swift:116-143`)
  전체를 `.accessibilityElement(children: .ignore)` 하나로 합쳐 라벨을 명시한다.
  힌트("끌어서 기울일 수 있어요")는 넣지 않는다 — VoiceOver 가 제스처를 가로채 드래그가 동작하지
  않으므로 힌트가 틀린 안내가 된다(`BusinessCard3DView.swift:127-129`).
- 라벨은 `MyCard.frontFaceAccessibilityLabel`/`backFaceAccessibilityLabel`
  (`MyCard+CardFaceLabel.swift:31-53`)이고 각각 "앞면. "/"뒷면. " 접두어로 시작한다. 3D 카드는
  `RealityView` 라 면 정보가 라벨에 없으면 어느 쪽을 보고 있는지 알 방법이 없기 때문이다
  (`MyCard+CardFaceLabel.swift:29-30`). 뒷면 라벨은 값 없는 링크(`github`/`linkedIn`/`blog`)를
  건너뛴다 — `BusinessCardFaceView` 의 `linkRow` 가 값 없으면 줄 자체를 안 그리는 규칙과 대칭이다.

### scenePhase

`shouldRunGyro` 가 `scenePhase == .active` 가 아니면 멈춘다. `onDisappear` 는 백그라운드
진입 때 돌지 않으므로, 제어센터·알림을 끌어내린 구간에서 센서가 계속 도는 것을 이 조건이
막는다(`CardInteractionPolicy.swift:46-47`).

네 조건(자이로 토글·Reduce Motion·VoiceOver·scenePhase·하드웨어 유무)은 어느 하나라도
막으면 `false` — 토글이 켜져 있어도 시스템 설정이 이긴다(`CardInteractionPolicy.swift:39-40`).
`BusinessCard3DView.isGyroActive`(`BusinessCard3DView.swift:233-242`)가 이 판정에 더해
"2D 를 그리는 동안에는 센서를 켜지 않는다"는 조건을 하나 얹는다 — 화면에 없는 회전에
배터리를 쓸 이유가 없다.

## 5) 튜닝 손잡이 표 — `Card3DMetrics`

| 상수 | 현재 값 | 무엇을 바꾸는지 | 실기기 육안 튜닝 대상 |
|------|---------|------------------|----------------------|
| `yawLimit` | 30° | 드래그/자이로 좌우 회전 상한 | 아니오 (전경축소율 계산에서 도출) |
| `pitchLimit` | 20° | 드래그/자이로 상하 회전 상한 | 아니오 (텍스트 3단 여유에서 도출) |
| `degreesPerPoint` | 0.25 | 드래그 1pt 당 회전량(도) | 아니오 (카드 폭 1/3 드래그 = 상한 기준으로 역산) |
| `returnDuration` | 0.3s | 손 뗀 뒤 rest 복귀 시간 | 아니오 (UIKit 기본 애니메이션 대역 참고) |
| `flipDuration` | 0.45s | 플립 애니메이션 시간 | 아니오 (지각 실험적 배율, 값 자체는 임의 조정 가능) |
| `motionInterval` | 1/60s | 자이로 콜백 주기 | **예** — 1/30 배터리 절약안이 실기기 측정 후 판단 대상 |
| `motionSmoothing` | 0.15 | 자이로 지수 평활 계수 | **예** — 정지 상태 센서 노이즈로 인한 떨림이 실측 후 조정 대상 |
| `cameraDistance` | 0.11m | 카메라-카드 거리 | 아니오 (fill 0.85 기준 계산값) |
| `fieldOfView` | 30° | 시야각(원근 왜곡) | 아니오 (스파이크 값 승계) |
| `keyLightIntensity` | 1,500 lux | 키 라이트 밝기 | **예** — `RealityViewEnvironment.default` IBL 만으로 충분한지 눈으로 봐야 함. 너무 밝아 하이라이트가 타면 이 값부터 내림 |
| `keyLightPosition` | `[0.06, 0.08, 0.15]` | 키 라이트 위치(우상단 전면) | **예** — 기울일 때 표면을 훑는 스페큘러 각도가 실기기 육안 튜닝 대상 |
| `CardRotation.rotated(roll:pitch:)` 의 부호 | `yaw = -roll` | 자이로 기울임 → 화면 회전 방향 매핑 | **예** — `CardRotation.swift:76-78` 주석이 "실기기에서 확인할 항목이다"라고 명시 |
| `cardAspectRatio` | 1.8 (템플릿 폭/높이) | 3D 표면 종횡비 | 아니오 (2D 카드 종횡비와 0.8% 차이로 고정) |

실기기 미검증 항목(자이로 주기·평활 계수·키 라이트 두 값·자이로 부호)은 코드 주석에서도
"실기기 육안 튜닝 대상"·"실기기에서 확인할 항목"으로 명시돼 있다(`Card3DMetrics.swift:45-51,62-73`,
`CardRotation.swift:76-78`). #1248이나 후속 튜닝 작업에서 값을 바꾸면 이 표도 갱신한다.

## 6) 뒷면의 현재 상태 (#1247 시점)

뒷면은 **흰 QR 정사각 + 자식 없는 링크 앵커**다(`BusinessCard3DView.swift:22-24`). 이는
버그가 아니라 앵커 규약이 정한 정상 중간 상태다:

- `MaterialSlot.qrSurface` 는 흰색 고정이고, QR 값을 주입하지 않으면 흰 정사각이 그대로 남아
  "빈 카드"가 아니라 "QR 없음"으로 보인다(`BusinessCardTemplate.swift:166-168`).
- `Anchor_LinkTop`/`Anchor_LinkMiddle`/`Anchor_LinkBottom` 은 #1247 시점에는 아무 자식도
  없다 — "앵커 없음"(에러)과 "값 없음"(정상, 자식 미생성)의 구분은
  `docs/claude/business-card-3d-anchor-contract.md` §2 를 따른다. #1248 이 `github`/`linkedIn`/`blog`
  값을 채워 넣는 합성기를 여기 연결한다.

## 7) 테스트 실행법

```bash
cd UMCApp && make test SCHEME=BusinessCardPresentation
```

기본 `SCHEME=UMCApp` 으로는 `BusinessCard3DInteractionTests`(`BusinessCard3DInteractionTests.swift:20`)
가 돌지 않는다 — 앱 스킴의 테스트 액션에 `BusinessCardPresentationTests` 타겟이 들어 있지 않다
(`docs/claude/business-card-3d-anchor-contract.md` §3 과 같은 사정).

이 테스트 스위트는 회전 기하(드래그 클램프, 플립 왕복, 자이로 매핑, 평활 수렴)와 인터랙션 정책
(Reduce Motion, VoiceOver/백그라운드/하드웨어 부재, 2D 폴백 분기)을 순수 값 타입 단정으로
잠근다. `BusinessCard3DScene`/`BusinessCard3DView` 자체는 여기서 테스트하지 않는다 — 씬
그래프와 SwiftUI 뷰라 테스트 비용이 값 타입보다 크고, 그쪽 회귀는 실기기 체크리스트가 잡는다
(`BusinessCard3DInteractionTests.swift:13-17`).

## 8) #1249 를 위한 주의 — 명함첩 그리드는 3D 를 쓰지 않는다

명함첩 그리드 셀은 `BusinessCard3DView` 를 그대로 재사용하지 않는다. 스파이크 실측치
(`docs/claude/business-card-3d-spike.md` "축 3 — 2D 스냅샷")에 따르면 256px 스냅샷 1장이
45.47~52.33ms 로, 스크롤 프레임 예산(16.7ms)의 3배다. 그리드 셀이 보일 때마다 3D 렌더를
돌리면 스크롤이 끊긴다.

#1249 는 카드 저장/수신 시점에 2D 스냅샷을 한 번 구워 디스크에 캐시하고, 그리드는 캐시된
이미지만 읽는 구조를 따라야 한다. `Card3DMetrics.cardAspectRatio`(§5)를 참고해 스냅샷 종횡비를
맞추면 그리드 셀과 상세 화면 사이 레이아웃 점프가 없다.

## 9) 트러블슈팅

- 증상: 3D 카드가 로드되지 않고 계속 2D(`BusinessCardFaceView`)만 보인다.
  - 원인: `makeEntity` 가 예외를 던져 `phase`(`CardScenePhase`)가 `.failed` 로 떨어졌다
    (`BusinessCard3DView.swift:270-273`). 또는 `dynamicTypeSize.isAccessibilitySize` 가
    `true` 라 로드 자체를 시도하지 않았다(`CardInteractionPolicy.swift:75`).
  - 해결: Console.app 에서 `subsystem: dev.umc.feature.businesscard, category: BusinessCard3D`
    로 필터링해 `"3D 카드 로드 실패, 2D 로 폴백: ..."` 로그를 확인한다. 접근성 글자 크기라면
    설정에서 Dynamic Type 을 표준 크기로 낮춰 재현되는지 본다.

- 증상: 카드가 검게(또는 무광으로) 렌더된다.
  - 원인: 템플릿 머티리얼이 `UsdPreviewSurface`(PBR)라 광원이 없으면 검게 나온다
    (`BusinessCard3DScene.swift:77`). `RealityViewEnvironment.default` 의 IBL 만으로 부족한
    경우다.
  - 해결: `Card3DMetrics.keyLightIntensity`/`keyLightPosition` 을 §5 표를 참고해 실기기에서
    조정한다. 하이라이트가 타면 `keyLightIntensity` 를 먼저 내린다.

- 증상: 자이로 버튼이 화면에 안 보인다.
  - 원인: 의도한 동작이다. `isGyroControlVisible`(`BusinessCard3DView.swift:246-248`)이
    `!reduceMotion && scene.isDeviceMotionAvailable` 일 때만 버튼을 보여준다 — 시뮬레이터에는
    자이로가 없어 플립 버튼만 남는다.
  - 해결: 실기기에서 확인한다. Reduce Motion 이 켜져 있다면 설정에서 끈다.

- 증상: 기기를 기울이는 방향과 카드가 도는 방향이 반대(또는 예상과 다르게) 느껴진다.
  - 원인: `CardRotation.rotated(roll:pitch:)`(`CardRotation.swift:79-85`)의 부호 매핑이
    실기기 미검증 항목이다 — 코드 주석 자체가 "실기기에서 확인할 항목이다"라고 명시한다.
  - 해결: 실기기에서 기기를 오른쪽으로 기울여 카드 오른쪽 모서리가 앞으로 나오는지 확인하고,
    반대면 `yaw: Self.clamped(Float(-roll), ...)` 의 부호를 뒤집는다. `pitch` 도 같은 방식으로
    검증한다.

- 증상: 정지 상태에서도 카드가 미세하게 떤다.
  - 원인: 자이로 센서 노이즈가 `Card3DMetrics.motionSmoothing`(0.15) 평활을 거쳐도 남는다.
  - 해결: `motionSmoothing` 값을 낮춰(0에 가깝게) 반응을 더 둔하게 만든다. 실측 후 조정
    대상으로 이미 표시돼 있다(`Card3DMetrics.swift:49-51`).

## 체크리스트 — #1248 착수 전 확인

- [ ] `BusinessCard3DView(..., makeEntity:)` 의 기본 클로저만 교체했는가 — 새 프로토콜을
      만들지 않았는가
- [ ] 합성기가 던지는 에러가 `phase = .failed` 로 이어져 2D 폴백이 정상 동작하는지
      `#Preview("합성 실패 폴백")` 패턴으로 확인했는가
- [ ] 합성 결과에 애니메이션 가능한 값을 추가했다면 SwiftUI 상태가 아니라
      `BusinessCard3DScene` 의 비관측 프로퍼티로 관리하는가
- [ ] `Anchor_LinkTop`/`Middle`/`Bottom` 에 "값 없음"과 "앵커 없음"을 구분해 처리하는가
      (`docs/claude/business-card-3d-anchor-contract.md` §2)
- [ ] `make test SCHEME=BusinessCardPresentation` 이 통과하는가 (기본 `SCHEME=UMCApp` 아님)
- [ ] 자이로 부호(`CardRotation.rotated`)·키 라이트 값을 실기기에서 육안으로 확인했는가
      (§5 표의 "실기기 육안 튜닝 대상" 항목)
