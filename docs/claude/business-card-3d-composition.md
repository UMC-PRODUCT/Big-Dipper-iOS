# 3D 명함 온디바이스 합성 파이프라인

#1248 이 만든 합성기 `BusinessCardComposer` 를 **어떻게 부르고, 무엇이 돌아오는가**에 집중한
문서다. 앵커 이름·좌표 규약·템플릿 재생성 파이프라인은 여기서 반복하지 않는다 —
`docs/claude/business-card-3d-anchor-contract.md` 소관이다. Phase 0 실측치의 출처는
`docs/claude/business-card-3d-spike.md` 다. 이 문서의 독자는 #1247(회전·상호작용 뷰)과
#1249(2D 스냅샷 캐시)를 구현하며 `compose` 를 실제로 호출하게 될 사람이다.

- 작성자: 제옹(euijjang97)
- 기준 코드:
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardComposer.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardTemplate.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Tests/BusinessCardComposerTests.swift`
  - `UMCApp/Core/UIComponents/Sources/Utilities/RemoteImageLoader.swift`
  - `UMCApp/Core/UIComponents/Tests/Utilities/RemoteImageLoaderTests.swift`
  - `UMCApp/Features/BusinessCard/Domain/Sources/Models/MyCard.swift`

## 1) 호출 방법 한눈에

진입점은 하나다. `BusinessCardComposer.swift:89-104`:

```swift
@MainActor
public enum BusinessCardComposer {
    public static func compose(
        _ card: MyCard,
        portrait: CGImage? = nil,
        qrImage: CGImage? = nil,
        partTint: Color? = nil
    ) async throws -> Entity

    nonisolated public static func partTint(for card: MyCard) -> Color?
}
```

최소 호출 형태 — 실제 뷰는 #1247 소관이므로 아래는 의도된 호출부 모양이다:

```swift
.task(id: card.memberId) {
    var portrait: CGImage?
    if let avatarURL = card.avatarURL {
        portrait = await RemoteImageLoader.cgImage(
            from: avatarURL,
            maxPixelSize: BusinessCardComposer.portraitPixelSize
        )
    }
    do {
        let entity = try await BusinessCardComposer.compose(
            card,
            portrait: portrait,
            partTint: BusinessCardComposer.partTint(for: card)
        )
        // 씬에 붙인다 — 소유권은 전적으로 호출자에게 있다.
    } catch is CancellationError {
        // 화면 이탈로 인한 정상 종료. 에러로 노출하지 않는다.
    } catch {
        // Loadable.failed 로 승격한다.
    }
}
```

- `portrait` 가 `CGImage` 인 이유: URL 을 받으면 다운로드가 합성기(메인 액터) 안으로 들어온다.
  다운로드·디코드는 메인 밖에 둘 수 있는 유일한 단계라(§2), 호출부가
  `RemoteImageLoader.cgImage(from:maxPixelSize:)` 로 먼저 받아 넘긴다
  (`BusinessCardComposer.swift:79-81`).
- `portraitPixelSize`(512px)는 `BusinessCardComposer.swift:49-51` 에 있다. 512px RGBA 텍스처
  1장 실측 926~932KB (`docs/claude/business-card-3d-spike.md` 축 1 표). 메모리를 줄여야 하면
  이 상수 하나만 낮춘다.
- `ReceivedCard` 도 같은 경로다 — `profile` 이 그대로 `MyCard` 라 받은 명함용 별도 API 가 없다
  (`BusinessCardComposer.swift:77-78`).

### 1-1) `partTint(for:)` 폴백 — 색을 못 정하면 `nil`

`BusinessCardComposer.swift:114-116`:

```swift
nonisolated public static func partTint(for card: MyCard) -> Color? {
    card.partRaw == nil ? card.part.seedColor : nil
}
```

`UMCPartType` 은 닫힌 열거형이라 서버가 보낸 모르는 파트는 `.admin` 으로 폴백되고 원본
문자열이 `MyCard.partRaw` 에 남는다 (`MyCard.swift:24-31`). 이때 `seedColor` 를 그대로 쓰면
**모르는 파트가 운영진 인디고로 위장된다.** 그래서 폴백은 「색 없음」이다 — `nil` 이면 칩
캡슐이 시안 기본값인 반투명 흰색(알파 0.22)으로 남는다 (`BusinessCardComposer.swift:322-329`).
중립 캡슐이 틀린 색보다 낫다는 판단이고, 테스트 12(`BusinessCardComposerTests.swift:241-249`)가
이 규칙을 잠근다. 합성기가 `UMCPartType` 을 직접 분기하지 않는 것도 같은 이유다 — 파트가
늘어나도 이 함수는 그대로다.

## 2) 동시성 경계 — 합성은 메인을 떠날 수 없다

**이 파이프라인의 핵심 제약이다.** 합성에 쓰는 RealityKit API 가 전부
`@preconcurrency @MainActor` 다 — `Entity`·`ModelEntity`·`MeshResource`·`TextureResource` 와
`generateText`·`generatePlane`·`TextureResource.init(image:withName:options:)`
(`BusinessCardComposer.swift:21-28` 도큐먼트 주석 참고). 백그라운드 액터에서 엔티티를 조립할
방법이 없으므로, 합성을 오프메인으로 「최적화」하려는 시도는 출발부터 막혀 있다.

경계는 이렇게 갈린다:

| 단계 | 어디서 도나 | 근거 |
|------|------------|------|
| 사진 다운로드·디코드·다운샘플 | 오프메인 (Kingfisher) | `RemoteImageLoader.swift:27-50` |
| 템플릿 로드·메시 생성·텍스처 주입·엔티티 조립 | 메인 액터 | `BusinessCardComposer.swift:44` 의 `@MainActor` |

메인을 못 떠나는 대신 **바인딩 한 단계마다 `breathe()` 로 런루프에 숨을 준다**
(`BusinessCardComposer.swift:339-342`):

```swift
private static func breathe() async throws {
    try Task.checkCancellation()
    await Task.yield()
}
```

스파이크 실측에서 워밍업 이후 합성 전체가 27~54ms 였으므로
(`docs/claude/business-card-3d-spike.md` 축 1 표 — 사진 제외 27.02~39.49ms · 포함
31.01~54.08ms), 단계별로 쪼개면 한 조각이 프레임 예산(16.7ms) 안에 들어간다는 계산이다.

주의할 점 두 가지:

- **`Task.yield()` 는 메인 런루프 양보를 보장하지 않는다.** 협조적 스레드풀에 재스케줄 기회를
  줄 뿐이다. 그래서 실기기 Instruments(Hangs) 측정이 남아 있고(§8), 블록이 16.7ms 를 넘으면
  이 한 줄을 `try await Task.sleep(for: .milliseconds(1))` 로 바꾸고 다시 잰다 — **동시성 조정
  손잡이는 여기 하나뿐이다** (`BusinessCardComposer.swift:331-338`).
- **취소는 `.task(id:)` 로 전파된다.** 호출부가 SwiftUI `.task(id:)` 안에서 부르면 화면 이탈·
  카드 전환 시 태스크 취소가 `breathe()` 의 `Task.checkCancellation()` 에 걸려
  `CancellationError` 로 던져진다. 테스트 15(`BusinessCardComposerTests.swift:274-280`)가
  「취소된 작업은 끝까지 합성하지 않는다」를 단정한다. `RemoteImageLoader` 는 취소를 `nil` 로
  삼키지만(`RemoteImageLoader.swift:44-49`), 합성기 쪽 `checkCancellation` 이 다시 확인하므로
  취소가 유실되지는 않는다.

이 모듈은 `SWIFT_STRICT_CONCURRENCY` 가 꺼져 있어 격리 위반을 컴파일러가 잡아 주지 않는다.
`@MainActor`/`nonisolated` 를 추론에 맡기지 말고 명시한다 (`BusinessCardComposer.swift:34-36`).

## 3) 바인딩 순서와 `ComposedPrim` 9종

`bind(_:portrait:qrImage:partTint:into:)` (`BusinessCardComposer.swift:125-175`)는 아래 순서로
붙이고, 각 단계 사이에 `breathe()` 를 끼운다:

이름 → 학교 → 파트 칩 → 기수 칩 → 사진 텍스처 → 링크 3줄 → QR 텍스처 → 최종 취소 확인

합성이 **만들어 붙이는** 엔티티 이름은 `ComposedPrim` 9종이다
(`BusinessCardComposer.swift:60-70`). 템플릿의 `RequiredPrim`(USDZ 에 있어야 하는 것)과 일부러
분리돼 있다 — 섞으면 계약 테스트가 합성 산출물까지 요구하게 된다. #1247 과 테스트가 이
이름으로 결과를 찾는다.

| ComposedPrim | 엔티티 이름 | 붙는 앵커 | 내용 |
|--------------|------------|-----------|------|
| `.name` | `Text_Name` | `Anchor_Name` | `MyCard.nameWithNickname` |
| `.university` | `Text_University` | `Anchor_University` | `university` |
| `.partChipCapsule` | `Capsule_PartChip` | `Anchor_PartChip` | 캡슐 평면 (§4) |
| `.partChipLabel` | `Text_PartChip` | `Anchor_PartChip` | `MyCard.partDisplayName` |
| `.generationChipCapsule` | `Capsule_GenerationChip` | `Anchor_GenerationChip` | 캡슐 평면 (§4) |
| `.generationChipLabel` | `Text_GenerationChip` | `Anchor_GenerationChip` | `"\(generation)기"` |
| `.linkTop` | `Text_LinkTop` | `Anchor_LinkTop` | 값 있는 링크 1번째 |
| `.linkMiddle` | `Text_LinkMiddle` | `Anchor_LinkMiddle` | 값 있는 링크 2번째 |
| `.linkBottom` | `Text_LinkBottom` | `Anchor_LinkBottom` | 값 있는 링크 3번째 |

사진(`Portrait`)과 QR(`QRSurface`)은 이 표에 없다 — 새 엔티티를 만들지 않고 템플릿 prim 의
머티리얼만 `UnlitMaterial(texture:)` 로 갈아 끼운다 (`BusinessCardComposer.swift:268-278`).

문자열 규칙은 전부 2D(`BusinessCardFaceView`)와 공유한다. 다르게 쓰면 같은 명함이 2D 와 3D
에서 다르게 읽히기 때문이다:

- 이름은 `MyCard.nameWithNickname` — 닉네임이 있으면 `"이름/닉네임"` (`MyCard.swift:78-81`).
- 파트는 `MyCard.partDisplayName` — 못 읽은 파트면 서버 원본 문자열 그대로 (`MyCard.swift:83-85`).
- 기수는 「12」가 아니라 「12기」 (`BusinessCardComposer.swift:155-164`).
- 링크 3줄은 `github → linkedIn → blog` 순으로 **값이 있는 것만 위에서부터 당겨 채운다**
  (`BusinessCardComposer.swift:181-199`) — 2D `linkRow(value:icon:)` 가 nil·빈 문자열 줄을
  건너뛰는 것과 같은 규칙이다. 단, 앵커는 값이 없어도 셋 다 존재를 확인한다 — 링크 1개짜리
  카드에서 앵커 실종이 숨으면 3개짜리 카드가 처음 도착할 때 터진다.

## 4) 칩 캡슐 기하 — 잉크 폭으로 감싼다

칩 = 캡슐(밑) + 라벨(위) 두 엔티티다 (`BusinessCardComposer.swift:225-263`). 치수는 폭
**예산**(`TextSlot.width`)이 아니라 라벨 메시의 실제 잉크 폭에서 나온다 — 2D `PartChip` 이
텍스트를 감싸는 방식과 같아야 「PM」 칩과 「Android」 칩의 리듬이 일치한다:

```swift
let ink = mesh.bounds.extents.x
let width = max(Chip.minWidth, ink + 2 * Chip.horizontalPadding)
let height = max(Chip.minHeight, slot.frameHeight + 2 * Chip.verticalPadding)

let capsule = ModelEntity(
    mesh: .generatePlane(width: width, height: height, cornerRadius: height / 2),
    materials: [capsuleMaterial(tint: tint)]
)
```

- 패딩·최소 치수는 2D `PartChip` 의 pt 값(가로 8pt · 세로 3pt · 최소 39×23pt)을
  `Geometry.millimetersPerPoint` 로 환산한 것이다 (`BusinessCardComposer.swift:348-365`).
  새 값을 만들지 않는다 — 2D 가 SSOT 다.
- `cornerRadius = height / 2` 라서 평면이 캡슐 모양이 된다.
- **`generateBox` 가 아니라 `generatePlane` 이다** — 두께 0.1mm 짜리 박스에 반지름 ~2.9mm 를
  주면 어떤 메시가 나오는지 알 수 없다 (`BusinessCardComposer.swift:244-245`).
- 칩 앵커의 x 는 **leading** 기준인데 `generatePlane` 은 원점 중심이라 캡슐을 `width / 2`
  만큼 오른쪽으로 민다 (`:251-254`).
- 라벨은 캡슐 안 가운데로 옮기되 `mesh.bounds.min.x`(좌측 사이드 베어링)를 빼 준다 — 빼지
  않으면 그만큼 오른쪽으로 치우친다 (`:257-258`). z 로는 `Chip.labelLift`(0.02mm)만큼 띄운다 —
  같은 평면에 두면 z-파이팅으로 글자가 깜빡인다 (`:354-355`).

## 5) 텍스트 메시 원점 정규화 — 보정은 한 곳에서 한 번만

`MeshResource.generateText(containerFrame:)` 에 상자를 주면 **메시 원점은 컨테이너의 좌측
하단**이고 글자는 상자 안 위쪽에 눕는다. 스파이크성 프로브로 실측한 값이다 — `name` 슬롯 상자
높이 7.317mm 에서 「가」 메시가 y 2.541~6.888mm 에 놓였다 (`BusinessCardComposer.swift:288-291`
주석에 기록). 그래서 `textEntity` 가 세로로 `frameHeight / 2` 만큼 내린다:

```swift
entity.position = SIMD3(0, -slot.frameHeight / 2, 0)
```

이러면 앵커 y 가 **상자의 세로 중앙**이 된다. 잉크 중앙이 아니라 상자 중앙에 맞추는 이유:
잉크로 맞추면 디센더 유무에 따라 같은 줄이 문자열마다 위아래로 흔들린다
(`BusinessCardComposer.swift:293-294`).

이 보정을 `textEntity` **한 곳에서만** 한다 (`:282-286`). 앵커마다 다른 보정값을 넣기 시작하면
좌표가 코드로 새어 나와 「좌표는 USDZ 가 들고 있다」는 규약
(`docs/claude/business-card-3d-anchor-contract.md` §1)이 무너진다. 결과가 틀어지면 고칠 곳은
`build_template.py` 의 좌표다.

## 6) 에러 vs 정상 부재 — 두 종류의 「없음」

원칙은 앵커 규약 문서 §2 와 같다 — 여기서는 합성기가 그 원칙을 어떻게 구현했는지만 적는다.

| 상황 | 처리 | 근거 |
|------|------|------|
| 규약 앵커가 템플릿에 없다 | `TemplateError.missingAnchor` throw — 합성 자체를 실패시킨다 | `BusinessCardTemplate.swift:213-218` |
| 번들에 USDZ 가 없다 | `TemplateError.assetMissing` throw | `BusinessCardTemplate.swift:190-200` |
| 값이 없다 (`github == nil`, 공백 문자열, 사진 없음) | 자식을 만들지 않거나 자리표시자를 건드리지 않는다. **에러가 아니다** | `BusinessCardComposer.swift:201-221`, `:265-274` |

값 없음이 조용해야 하는 반면 **빈 문자열은 반드시 걸러야 한다.** 빈 문자열로
`generateText` 를 부르면 CoreText 가 에러 없이 빈 메시를 주고 그 `bounds` 는 무한대가 된다 —
그 엔티티가 씬에 들어가면 #1247 의 카메라 프레이밍이 무한대에 끌려가 카드가 화면 밖으로
날아간다 (`BusinessCardComposer.swift:295-297`, 테스트 8 `BusinessCardComposerTests.swift:155-162`).
그래서 `textEntity` 가 트림 후 빈 값이면 `nil` 을 돌려주고 자식을 만들지 않는다 (`:303-304`).

`RemoteImageLoader` 도 같은 철학이다 — **실패를 던지지 않는 것이 계약이다**
(`RemoteImageLoader.swift:24-26`). 「사진이 없다」와 「사진을 못 받았다」는 같은 화면
(자리표시자)으로 끝나므로 구분할 이유가 없고, 구분이 필요한 실패는 그 위(합성·렌더)에서 던진다.

## 7) 캐시하지 않는 이유

`BusinessCardComposer` 는 무상태다 — 엔티티 캐시가 없다 (`BusinessCardComposer.swift:38-43`).

RealityKit 엔티티는 부모를 하나만 가진다. 캐시한 루트를 두 번째 화면에 넣으면 첫 번째
화면에서 카드가 **사라진다** — 캐시 히트가 곧 버그가 된다. 비싼 부분(HTTP·디코드)은
Kingfisher 가 이미 캐시하고, 명함첩 그리드의 다장 표시 문제는 #1249 의 2D 스냅샷 캐시가 푼다.
무상태라서 「명함 여러 장이 오가도 누수 없음」이 자명하게 참이고, 테스트 14
(`BusinessCardComposerTests.swift:264-270`)가 합성 결과의 해제를 실제로 단정한다.

## 8) 다음 이슈로 넘긴 것

- **#1247 — 회전·상호작용 뷰.** `compose` 결과를 `RealityView` 에 넣고 제스처·카메라 프레이밍을
  붙이는 쪽. 합성기의 `#Preview`(`BusinessCardComposer.swift:368-389`)는 합성 결과 눈 확인용일
  뿐 화면이 아니다.
- **#1249 — 2D 스냅샷 캐시·prewarm.** 명함첩 그리드는 장당 45~52ms 라 실시간 렌더가 불가하고
  캐시 전제다. RealityKit 최초 초기화(시뮬레이터 실측 9.4~11.6초)를 흡수할 워밍업 지점 결정도
  이쪽 소관이다 (`docs/claude/business-card-3d-spike.md` 「첫 진입 비용」).
- **온디바이스 Instruments(Hangs) 실측이 아직 없다.** `breathe()` 의 `Task.yield()` 가
  실기기에서 메인 스레드 블록을 실제로 프레임 예산 안에 눌러 주는지는 측정 전이다. 스파이크
  수치는 전부 시뮬레이터 값이므로, #1247 에서 실기기로 재야 §2 의 조정 손잡이를 돌릴지 말지
  정할 수 있다.

## 9) 체크리스트 — `compose` 를 새로 배선할 때

- [ ] 사진은 `RemoteImageLoader.cgImage(from:maxPixelSize:)` 로 **먼저 오프메인에서** 받아
      `CGImage` 로 넘겼는가 — URL 을 합성기 안으로 들이지 않는다
- [ ] `maxPixelSize` 에 `BusinessCardComposer.portraitPixelSize` 를 넘겼는가 — 숫자를 새로
      만들지 않는다
- [ ] `partTint` 에 `BusinessCardComposer.partTint(for:)` 결과를 그대로 넘겼는가 —
      `seedColor` 를 직접 꺼내면 모르는 파트가 운영진 색으로 위장된다 (§1-1)
- [ ] 호출을 `.task(id:)` 안에 두어 화면 이탈·카드 전환 시 취소가 전파되는가
- [ ] `CancellationError` 를 화면 에러(`Loadable.failed`·ErrorHandler)로 노출하지 않는가 —
      취소는 정상 종료다
- [ ] 합성 결과를 어딘가에 캐시하려 하지 않는가 — §7. 다장 표시는 #1249 의 스냅샷으로 푼다
- [ ] 테스트는 `cd UMCApp && make test SCHEME=BusinessCardPresentation` 으로 돌렸는가 —
      기본 `SCHEME=UMCApp` 에는 이 타겟이 없다

## 10) 트러블슈팅

- 증상: 합성이 `TemplateError.missingAnchor` 로 실패한다.
  - 원인: 템플릿에서 규약 prim 이 지워졌거나 이름이 바뀌었다. 합성기 문제가 아니라 에셋 계약
    위반이다.
  - 해결: `docs/claude/business-card-3d-anchor-contract.md` §7 트러블슈팅의 같은 항목을 따른다.
    계약 테스트 1(앵커 전수 존재)이 어떤 케이스가 빠졌는지 가리킨다.

- 증상: 합성이 `TemplateError.assetMissing` 으로 실패한다.
  - 원인: 리소스 배선이 끊겼거나, `BusinessCardTemplate.bundledURL` 을 다른 타겟에서 직접
    불렀다 — `Bundle.module` 은 선언한 모듈의 번들로만 해석되므로 테스트 타겟에서 부르면
    테스트 번들을 뒤지다 실패한다 (`BusinessCardTemplate.swift:186-200`).
  - 해결: 템플릿 접근은 항상 `BusinessCardTemplate.load()` 를 거친다. 리소스 배선은
    `presentationResources` 설정을 확인한다.

- 증상: 사진 자리가 회색 자리표시자 그대로다. 에러는 없다.
  - 원인: `RemoteImageLoader` 가 `nil` 을 돌려줬다 — URL 파싱 실패·네트워크 실패·취소 모두
    계약상 `nil` 이다 (`RemoteImageLoader.swift:27-49`). 합성기는 `nil` 이면 머티리얼을
    건드리지 않으므로 (`BusinessCardComposer.swift:265-274`) 템플릿의 자리표시자가 남는다.
  - 해결: 정상 동작이다. 「사진 없음」과 「사진 못 받음」을 화면에서 구분해야 하는 요구가
    생기면 이 계약 위(호출부)에서 실패를 따로 던지도록 설계한다.

- 증상: 3배 스케일 화면에서 사진 텍스처가 예상(0.93MB)의 수 배 메모리를 먹는다.
  - 원인: `DownsamplingImageProcessor` 는 목표 크기를 pt 로 보고 화면 스케일을 곱한다.
    `.scaleFactor(1)` 이 빠지면 512 목표가 1536px 로 올라가 카드 한 장이 8MB 선까지 커진다.
  - 해결: `RemoteImageLoader.swift:33-38` 의 옵션을 그대로 쓴다.
    `RemoteImageLoaderTests.swift:21-51` 이 「목표 크기를 픽셀로 해석한다」를 잠가 두었다 —
    눈으로는 안 보이는 회귀라 이 테스트가 유일한 방어선이다.

- 증상: 합성 중 스크롤·애니메이션 프레임이 눈에 띄게 끊긴다.
  - 원인: `breathe()` 의 `Task.yield()` 는 메인 런루프 양보를 보장하지 않는다
    (`BusinessCardComposer.swift:337-338`). 기기·부하에 따라 한 조각이 16.7ms 를 넘을 수 있다.
  - 해결: 실기기 Instruments(Hangs)로 합성 구간을 잰다. 블록이 예산을 넘으면
    `BusinessCardComposer.swift:339-342` 의 `await Task.yield()` 를
    `try await Task.sleep(for: .milliseconds(1))` 로 바꾸고 다시 잰다 — 조정 손잡이는 이 한
    곳뿐이다.

- 증상: 명함 화면을 두 개 띄우자 먼저 뜬 화면에서 카드가 사라진다.
  - 원인: 같은 `Entity` 인스턴스를 두 씬에 넣었다. RealityKit 엔티티는 부모가 하나뿐이라
    나중에 붙인 쪽이 카드를 뜯어 간다 — 합성 결과를 캐시·공유하면 반드시 이렇게 된다.
  - 해결: 화면마다 `compose` 를 새로 부른다 (§7). 웜 합성은 27~54ms 라 재합성 비용이 문제되지
    않고, 그마저 아까운 그리드는 #1249 의 2D 스냅샷을 쓴다.
