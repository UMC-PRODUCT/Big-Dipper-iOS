# 3D 명함 베이스 USDZ 템플릿 · 바인딩 앵커 규약

#1246 이 정한 규약을 **코드에서 어떻게 참조하는가**에 집중한 문서다. 좌표 도출 근거·시안 pt→mm
환산·WCAG 대비 계산 같은 설계 전문은 이 문서에서 반복하지 않는다 — #1247(회전)·#1248(온디바이스
합성)을 구현할 때 실제로 열어 보게 되는 Swift 심볼·테스트·재생성 커맨드가 이 문서의 범위다.
Phase 0(#1245) 스파이크 실측치는 `docs/claude/business-card-3d-spike.md` 를 본다.

- 작성자: 제옹(euijjang97)
- 기준 코드:
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardTemplate.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Resources/BusinessCardTemplate.usdz`
  - `UMCApp/Features/BusinessCard/Presentation/Tests/BusinessCardTemplateContractTests.swift`
  - `tools/card-template/build_template.py`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Components/BusinessCardFaceView.swift`
  - `UMCApp/Core/UIComponents/Sources/Extensions/UMCPartType+Color.swift`
  - `UMCApp/Features/BusinessCard/Presentation/Sources/Spike/BusinessCard3DSpike.swift`
  - `UMCApp/Tuist/ProjectDescriptionHelpers/Project+Feature.swift`

> 위 목록 중 `BusinessCardTemplate.swift`·`BusinessCardTemplateContractTests.swift`·
> `build_template.py`·`BusinessCardTemplate.usdz` 는 #1246 작업으로 새로 생기는 파일이다.
> 아래에서 이 파일들을 인용할 때는 규약 설계서가 확정한 API 형태를 근거로 쓰되, **행 번호는
> 붙이지 않는다** — 실제 코드가 들어온 뒤 확인한다.

## 1) Swift SSOT — `BusinessCardTemplate` enum

앵커 이름·지오메트리 치수·머티리얼 슬롯 이름은 전부 `BusinessCardTemplate.swift` 한 파일에
모인다. **`"Anchor_Name"` 같은 문자열을 호출부에 직접 적지 않는다** — 오타가 나면 컴파일은
통과하고 `findEntity(named:)` 가 조용히 `nil` 을 돌려주는 것으로만 드러난다. 대신 아래 세
네임스페이스를 거친다.

```swift
public enum BusinessCardTemplate {

    /// 카드 실물 치수(미터). 90×50×0.6mm, cornerRadius 8.293mm.
    public enum Geometry {
        public static let width: Float = millimeters(90)
        public static let height: Float = millimeters(50)
        public static let depth: Float = millimeters(0.6)
        public static let cornerRadius: Float = millimeters(8.293)
        public static let millimetersPerPoint: Float = 50.0 / 205.0
    }

    /// 템플릿에 반드시 있어야 하는 prim. 계약 테스트가 이 목록을 그대로 순회한다.
    public enum RequiredPrim: String, CaseIterable, Sendable {
        case cardBody = "CardBody"
        case faceFront = "Face_Front"
        case faceBack = "Face_Back"
        case portrait = "Portrait"
        case qrSurface = "QRSurface"
        case anchorName = "Anchor_Name"
        case anchorUniversity = "Anchor_University"
        case anchorPartChip = "Anchor_PartChip"
        case anchorGenerationChip = "Anchor_GenerationChip"
        case anchorLinkTop = "Anchor_LinkTop"
        case anchorLinkMiddle = "Anchor_LinkMiddle"
        case anchorLinkBottom = "Anchor_LinkBottom"
    }

    /// USD 머티리얼 슬롯. 이 셋 외에는 템플릿에 없어야 한다.
    public enum MaterialSlot: String, CaseIterable, Sendable {
        case cardSurface = "CardSurface"
        case portraitSurface = "PortraitSurface"
        case qrSurface = "QRSurface"
    }

    /// 텍스트 슬롯의 폭 예산·폰트. fontSize·width·frameHeight·weight 필드를 가진다.
    public struct TextSlot: Sendable { /* ... */ }
}
```

바인딩 코드는 앵커를 항상 `RequiredPrim` 케이스를 거쳐 찾는다:

```swift
guard let anchor = root.findEntity(named: BusinessCardTemplate.RequiredPrim.anchorName.rawValue) else {
    throw TemplateError.missingAnchor(BusinessCardTemplate.RequiredPrim.anchorName.rawValue)
}
```

`@MainActor` 인 이유는 `load()` 가 RealityKit `Entity` 를 만들기 때문이다. `Geometry`·
`RequiredPrim`·`MaterialSlot` 처럼 상수만 쓰는 곳까지 격리할 근거는 아직 없어 열지 않는다 —
필요해지면 그때 `nonisolated` 를 붙인다.

`public` 인 이유는 핵심 규칙 #4(모듈 간 노출 타입은 `public`)와, `#1249` 의 썸네일 캐시가
`Geometry` 의 종횡비를 다른 모듈에서 읽어야 하기 때문이다. `BusinessCardDomain` 은 이 enum 을
모른다 — 밀리미터·앵커 이름·머티리얼은 렌더링 관심사라 Presentation 레이어(`BusinessCardPresentation`)
에만 둔다. Domain 이 RealityKit 을 알게 되는 순간 Clean Architecture 경계가 깨진다.

로드는 `Entity(contentsOf:)` 가 파일을 **이름 없는 래퍼 엔티티**로 감싸 돌려준다는 사실 위에
서 있다. 그래서 루트 이름에 기대지 않고, 어디서든 `findEntity(named:)` 로 규약 prim 을 찾는다.

## 2) 「앵커 없음」과 「값 없음」 — 두 종류의 빈 상태

합성 코드가 마주치는 "비어 있음"은 원인이 다른 두 가지이고, 섞으면 안 된다.

| 상황 | 정상인가 | 처리 |
|------|----------|------|
| 템플릿에 규약 앵커가 없다(오타·리네임·삭제) | 아니다 | `throw TemplateError.missingAnchor(name)` — 합성 자체를 실패시킨다 |
| 바인딩할 **값**이 없다(`github == nil`, `avatarURL` 없음) | 정상 경로다 | 그 앵커 아래에 자식 엔티티를 만들지 않는다. 에러가 아니다 |

두 번째가 정상인 이유는 2D 쪽에 이미 같은 규칙이 있기 때문이다. `BusinessCardFaceView.swift:284-291`
의 `linkRow(value:icon:)` 는 `value` 가 `nil`이거나 빈 문자열이면 그 줄 자체를 그리지 않는다 —
"시안이 값 없는 줄을 지우고 위로 당긴다"는 규칙을 3D 도 그대로 물려받는다. 그래서 `Anchor_LinkTop`
아래에 자식이 없는 상태는 버그가 아니라 `github`·`linkedIn`·`blog` 셋 중 앞에서부터 채워 넣다가
값이 모자란 것뿐이다.

반대로 **앵커 자체가 비었다는 것으로는 고장을 판단할 수 없다.** 판단은 항상 템플릿 로드 시점에
`RequiredPrim.allCases` 를 전수 조회해서 끝나야 한다 — 로드가 통과했는데 특정 앵커 아래 자식이
없다면 그건 "그 필드가 비어 있었다"는 뜻으로 읽는다.

## 3) 계약 테스트 6종

**타겟**: `BusinessCardPresentationTests` (`BusinessCard/Project.swift` 에 이미
`includesPresentationTests: true` 로 존재)
**파일**: `Features/BusinessCard/Presentation/Tests/BusinessCardTemplateContractTests.swift`
**실행**: `cd UMCApp && make test SCHEME=BusinessCardPresentation`

| # | 테스트 | 단정 | 잡는 사고 |
|---|--------|------|-----------|
| 1 | 규약 앵커 전수 존재 | `RequiredPrim.allCases` 전부 `root.findEntity(named:) != nil` | 디자이너가 prim 을 리네임/삭제 — 이 이슈의 핵심 리스크 |
| 2 | 이름 유일성 | 트리를 순회해 모은 이름 배열에 중복 없음 | `findEntity` 가 첫 매치만 주므로, 중복이 있으면 엉뚱한 면에 바인딩된다 |
| 3 | 카드 치수 | `CardBody` mesh `bounds.extents` ≈ `(0.090, 0.050, 0.0006)` (허용 오차 1e-5) | `metersPerUnit` 오설정 — 카드가 100배로 로드돼도 에러가 나지 않는다 |
| 4 | 면 방향 | `Face_Front` 아래 앵커 전부 월드 `z > +0.0003`, `Face_Back` 아래 전부 `z < −0.0003` | `rotateY` 표기 실수. `usdchecker` 는 통과시킨다 |
| 5 | 한글 슬롯 무결성 | 규약 폰트·슬롯 폭으로 한글 표본(`황보정민아/민아` 포함) 메시를 만들어 `bounds.extents.x > 0` 이고 슬롯 폭 이내 | 1.25× 프레임 높이 버그 — 라틴 표본으로는 절대 안 잡힌다 |
| 6 | 앵커 카드 안쪽 | 전 앵커 월드 `(x, y)` 가 `[−45,45] × [−25,25]` 안 | 디자이너가 앵커를 카드 밖으로 끌었을 때 |

테스트 1·2·3·4·6 은 번들 USDZ 를 `BusinessCardTemplate.load()` 로 실제 로드해서 돈다. 테스트 5
는 번들 로드와 무관하게 `MeshResource.generateText` 를 규약 슬롯 폭·폰트로 직접 호출해 프레임
높이 회귀를 잡는다.

> **합성 결과(어느 앵커에 무엇이 실제로 붙었는지)에 대한 단정은 여기 없다.** 그건 #1248 이 다룬다.
> 이 타겟은 "에셋이 규약을 지키는가"만 본다 — 두 관심사를 섞으면 아트워크 교체가 합성 테스트를
> 깨뜨리게 된다.

**`make test` 의 기본 스킴(`SCHEME=UMCApp`)으로는 이 테스트가 돌지 않는다.** 앱 스킴의 테스트
액션에 `BusinessCardPresentationTests` 가 들어 있지 않다(`docs/claude/business-card-3d-spike.md:180-181`
과 같은 사정). `SCHEME=BusinessCardPresentation` 을 반드시 지정한다.

## 4) 템플릿 재생성 파이프라인

**진실 원천은 `.usda`/`.usdz` 가 아니라 `tools/card-template/build_template.py` 다.** 앵커
좌표표를 딕셔너리로 담고 있고, 규약을 고치는 곳은 이 스크립트 한 곳이다.

```bash
python3 tools/card-template/build_template.py     # .usda + cardSurface.png 생성
usdcat  -o BusinessCardTemplate.usdc BusinessCardTemplate.usda
usdzip  BusinessCardTemplate.usdz BusinessCardTemplate.usdc cardSurface.png
usdchecker BusinessCardTemplate.usdz --arkit       # Success! 를 확인
```

`usdcat`·`usdzip`·`usdchecker` 는 macOS 26 `/usr/bin` 에 이미 있다 — 추가 설치가 필요 없다.
Makefile 은 이 파이프라인을 `make card-template` 타겟으로 감싼다. **`make generate` 에는 엮지
않는다** — 템플릿은 규약이 바뀔 때만 다시 굽는 것이고, 매 generate 마다 파이썬 단계를 태우는
것은 순비용이다.

`.usda`(텍스트, 리뷰용)와 `.usdz`(바이너리, 빌드 입력)를 **둘 다 커밋한다.** `.usdz` 만 커밋하면
좌표 한 칸이 틀려도 PR diff 에 보이지 않는다 — 이 규약의 리스크가 정확히 "좌표·이름이 조용히
어긋나는 것"이므로, 리뷰 가능한 텍스트 형태가 레포에 반드시 있어야 한다는 것이 이 결정의 이유다.
`.usda` 만 커밋하면 `tuist generate`/빌드 앞에 코드 생성 단계가 붙는데, 그 비용이 6.4KB 바이너리
하나보다 크다.

> **`.usda` 를 고쳤으면 반드시 `make card-template` 을 돌린다.** 앵커를 추가·리네임하는 실수는
> §3 의 계약 테스트가 잡아준다(테스트가 번들 `.usdz` 를 로드하므로). 하지만 **기존 앵커의 좌표만
> 바꾸고 다시 굽는 것을 잊으면 테스트가 통과한 채로 넘어간다** — 좌표 자체를 검증하는 테스트가
> 없기 때문이다(§3 표의 6개는 존재·유일성·치수·방향·슬롯 폭·범위만 본다). 이게 이 파이프라인에서
> 유일하게 계약 테스트로 못 잡는 케이스이고, PR 체크리스트 항목으로 남겨 둘 가치가 있다.

## 5) 파트 색 SSOT — `UMCPartType.seedColor`

파트 악센트 색의 단일 진실 원천은 `UMCApp/Core/UIComponents/Sources/Extensions/UMCPartType+Color.swift:25-50`
의 `seedColor` 다. `color`(`:53-73`) 와 일부러 분리돼 있다 — `color` 는 Activity·Notice 가 이미
쓰는 시스템 컬러라, `seedColor` 를 시안 hex 로 갈아 끼우면 명함과 무관한 화면 색이 같이 바뀐다
(`:15-18` 주석). `UMCPartTypeSeedColorTests.swift:19-28` 이 8종 hex 를 잠가 두었고, `:35-40` 이
구별성을, `:44-50` 이 `.admin` 포함 전수 커버리지를 단정한다.

**스파이크가 쓰던 경쟁 표는 이 이슈에서 삭제됐다.** `BusinessCard3DSpike.swift:257-270` 의
`accentColor(for:)` 는 `.systemGray/.systemPurple/.systemPink/.systemGreen` + 고정 RGB 5갈래로
뭉갠 별개 테이블이었고, `associated value` 를 보지 않아 Spring/Node·Web/Android/iOS 를 구분하지
못했다. `#1246` 의 스파이크 쪽 변경은 이 함수를 지우고 카드 몸통을
`CardSurface` 기본색(`indigo500` `#4869F0`)으로 바꾸는 것뿐이다 — `Text_*`/`PhotoPlane` 같은
스파이크 이름·앵커 마이그레이션은 건드리지 않는다. 스파이크는 `#if DEBUG` 하네스이고 Phase 1이
끝나면 통째로 지워질 코드이므로, 이 이슈에서 정합성을 맞추는 건 딱 이 한 줄이다.

3D 템플릿 자체에는 `partTint: Color?` 슬롯이 정의돼 있지만 기본값은 `nil` 이다. 시안 `명함_l`
(3D 대상)에는 파트색이 한 픽셀도 없기 때문에, 값을 넣지 않는 한 칩은 중립 캡슐(흰색 알파 0.22)
로 남는다. 값을 주면 두 칩(`Anchor_PartChip`·`Anchor_GenerationChip`)의 캡슐 면색만 바뀐다 —
`partTint` 가 `seedColor` 로 이어지는 유일한 진입점이다. 명함첩 그리드 스냅샷에 파트색을 넣을지는
#1249 가 디자인팀과 확정한다.

## 6) 체크리스트 — #1247·#1248 착수 전 확인

- [ ] 앵커 이름 문자열을 직접 쓰지 않고 `BusinessCardTemplate.RequiredPrim` 케이스를 거쳤는가
- [ ] "값 없음"과 "앵커 없음"을 구분해서 처리했는가 — 값이 없으면 자식만 안 만들고, 앵커가 없으면
      `TemplateError.missingAnchor` 를 던지는가
- [ ] 텍스트 메시의 `containerFrame.height` 를 `fontSize × 1.5` 로 고정했는가(§7 트러블슈팅 참고)
- [ ] `Face_Back` 계열 회전을 `double xformOp:rotateY = 180`(스칼라)로 확인했는가 — `double3` 로
      쓰면 `usdchecker` 는 통과하지만 회전이 적용되지 않는다
- [ ] 파트색이 필요한 화면이면 `partTint` 를 명시로 넣었는가 — 기본값 `nil` 은 중립 캡슐이다
- [ ] `.usda` 좌표를 고쳤으면 `make card-template` 을 돌려 `.usdz` 를 재생성했는가
- [ ] `make test SCHEME=BusinessCardPresentation` 을 돌려 계약 테스트 6종이 전부 통과하는가
      (기본 `SCHEME=UMCApp` 으로는 이 테스트가 실행되지 않는다)

## 7) 트러블슈팅

- 증상: 한글 이름·학교 줄이 3D 카드에서 통째로 안 보인다(빈 카드).
  - 원인: 텍스트 메시의 `containerFrame.height` 를 시안 `lineHeight` 비율(title3 = 1.25 × fontSize)
    로 주면 한글 폴백 폰트의 라인 높이가 상자에 안 들어가서 CoreText 가 에러 없이 아무것도 그리지
    않는다. 라틴 문자열은 같은 상자에서 멀쩡히 나오므로 영어 더미로 테스트하면 절대 재현되지 않는다.
  - 해결: `containerFrame.height` 를 `fontSize × 1.5` 로 고정한다. §3 테스트 5(한글 슬롯 무결성)가
    한글 표본으로 이 회귀를 잡는다 — 실패하면 프레임 높이 계산부터 의심한다.

- 증상: 명함 뒷면 앵커(`Anchor_LinkTop` 등)가 거울반전되지 않고 카드 안쪽에 파묻힌 좌표로 잡힌다.
  - 원인: `Face_Back` 의 회전을 `double3 xformOp:rotateY = (0, 180, 0)` 로 적으면 `usdchecker --arkit`
    은 통과하지만 RealityKit 로드 시 회전이 적용되지 않는다 — 뒷면 앵커의 월드 x 가 앞면과 같은
    부호로 남고 z 도 카드 바깥이 아니라 안쪽에 놓인다.
  - 해결: 스칼라 `double xformOp:rotateY = 180` 으로 표기한다. §3 테스트 4(면 방향)가 `Face_Back`
    아래 전 앵커의 월드 `z < −0.0003` 을 단정하므로, 이 버그가 있으면 테스트 4가 바로 떨어진다.

- 증상: 카드가 화면에서 100배 크게(또는 작게) 로드된다. 에러 로그는 없다.
  - 원인: `.usda` 스테이지 메타데이터의 `metersPerUnit` 이 `1` 이 아니게(예: cm 저작 습관으로 `0.01`)
    나갔다. RealityKit 은 USD 좌표를 항상 미터로 해석하므로, `metersPerUnit` 이 어긋나면 프레임 안의
    모든 좌표가 그 배율만큼 스케일되고 로드 자체는 성공한다.
  - 해결: `.usda` 헤더에 `metersPerUnit = 1` 을 확인한다. §3 테스트 3(카드 치수)이 `CardBody` 의
    `bounds.extents` 를 `(0.090, 0.050, 0.0006)` 과 1e-5 오차로 비교하므로, 스케일이 어긋나면 즉시
    실패한다.

- 증상: `TemplateError.missingAnchor` 가 런타임(또는 계약 테스트)에서 던져진다.
  - 원인: `.usda` 를 편집하며 `Anchor_` prim 을 지웠거나 이름을 바꿨다. Reality Composer Pro 로
    아트워크만 옮기려다 prim 이름까지 바뀌는 경우가 흔하다.
  - 해결: §3 테스트 1(규약 앵커 전수 존재)의 실패 메시지가 어떤 `RequiredPrim` 케이스가 빠졌는지
    가리킨다. `build_template.py` 의 앵커 좌표표에서 이름을 원복하고 `make card-template` 을 다시
    돌린다.

- 증상: `findEntity(named:)` 가 의도한 것과 다른 면의 앵커를 돌려준다(예: 뒷면 링크에 앞면 텍스트가
  바인딩됨).
  - 원인: 앞/뒷면에 같은 이름의 prim 이 존재한다. `findEntity` 는 서브트리를 훑어 **첫 매치**만
    돌려주므로 이름이 겹치면 조용히 엉뚱한 면에 바인딩된다.
  - 해결: §3 테스트 2(이름 유일성)가 트리 전체에서 중복 이름을 잡는다. 앞/뒷면은 이름이 아니라
    `Face_Back` 의 `rotateY = 180` Xform 으로만 구분해야 한다 — 사진(`Portrait`)과 QR(`QRSurface`)
    처럼 시안에서 자리가 같아 보여도 이름은 반드시 다르게 짓는다.
