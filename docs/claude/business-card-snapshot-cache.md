# 명함첩 그리드 2D 스냅샷 캐시

> 이슈 #1249 구현의 설계 근거 기록. 스파이크 실측은 `docs/claude/business-card-3d-spike.md`,
> 이 문서는 그 결론(「캐시 전제」)을 제품 코드로 옮기며 내린 결정들을 남긴다.
> **이 캐시에는 명시적 무효화 API 가 없고, 그것이 설계다** — 「캐시 클리어 함수」를 추가하기 전에
> 「무효화 매트릭스」 절을 먼저 읽을 것.

- 작성자: 제옹(euijjang97)

## 왜 스냅샷인가

명함첩 그리드는 3D 카드를 직접 그리지 않는다. 스파이크(#1245) 실측이 근거다:

| 실측 (#1245) | 값 | 결론 |
|------|-----|------|
| RealityKit 첫 합성 | 9.42 ~ 11.62s | 그리드 진입 때마다 낼 수 없는 비용 |
| 웜 합성 1장 | 31 ~ 54ms | 프레임 예산 16.7ms 의 2~3배 |
| 스냅샷 장당 렌더 | 45 ~ 52ms | 셀이 보일 때마다 굽으면 스크롤이 끊긴다 |

그래서 그리드는 `RealityView` 를 **절대 만들지 않고**(`BusinessCardSnapshotRenderer.swift:20-24`),
뷰 계층 없는 `RealityRenderer` 로 오프스크린 텍스처에 한 번 구운 2D 이미지를 캐시에서 읽는다.
캐시는 새로 만들지 않았다 — 이미 링크된 Kingfisher `ImageCache` 하나가 메모리 cost 상한·디스크
바이트 상한·만료·LRU 트리밍·오프메인 IO 를 전부 갖고 있다(`BusinessCardSnapshotProvider.swift:14-19`).

```
ReceivedCardSnapshotCell ──(120ms 정착)──▶ SnapshotProvider ──▶ SnapshotRenderer ──▶ SnapshotComposer(임시)
        │                                   메모리 → 디스크 → 굽기                        └ #1248 머지 시 삭제
        └ 폴백·사이징: ReceivedCardCell (2D, ZStack 하단 상시)
```

## 캐시 키 — 키가 곧 무효화

키는 **그려질 픽셀을 결정하는 입력의 전체 집합**이다(`BusinessCardSnapshotProvider.swift:179-188`).
입력이 하나라도 달라지면 키가 달라지고, 달라진 키는 정의상 캐시 미스라 새로 굽는다. 그래서
「무효화」라는 별도 동작·플래그·버전 테이블·클리어 함수가 없다. 옛 이미지는 참조되지 않은 채
남았다가 TTL·LRU 로 사라진다. **캐시 클리어 API 를 추가하면 이 불변식이 깨진다** — 지워야 할
상황이 생겼다면 답은 클리어 호출이 아니라 「그 입력을 키에 넣는 것」이다.

단, 키가 달라지는 것만으로는 부족하다 — **뷰 계층이 그 키를 다시 조회해야 무효화가 실제로
발동한다.** 셀은 `.task(id: BusinessCardSnapshotProvider.key(for: card))` 로 키 자체를
감시한다(`ReceivedCardSnapshotCell.swift:72-76`). 재교환은 같은 `ReceivedCard.id` 로 upsert 라
`profile` 만 바뀌는데, id 만 보고 있으면 뷰가 키 변경을 못 보고 옛 이미지가 그대로 남는다.

컴포넌트와 순서(`BusinessCardSnapshotProvider.swift:195-241`):

| # | 컴포넌트 | 왜 키에 있나 |
|---|---------|-------------|
| 1 | 앱 버전 `{version}+{build}` | 렌더러·템플릿·레이아웃 변경은 반드시 릴리스를 탄다. 사람이 상수를 올리는 걸 잊어도 전량 자동 무효화 (`:197-214`) |
| 2 | (DEBUG 한정) 실행 파일 수정 시각 | 디버그는 릴리스 번호가 안 오른다 — 재컴파일을 잡아야 템플릿을 만져도 옛 이미지가 안 남는다 (`:203-213`) |
| 3 | 픽셀 크기 `512x288` | `Metrics.snapshotPixelSize` 를 바꾸면 전량 자동 무효화 (`:47-50`, 키 삽입은 `:225`) |
| 4 | 색상 스킴 `UITraitCollection.current.userInterfaceStyle.rawValue` | **선제 컴포넌트** — 아래 세부 결정 참고 (`:226-231`) |
| 5~11 | `memberId` · `name` · `nickname` · `partAPIValue` · `generation` · `university` · `avatarURL ?? ""` | 카드 앞면에 찍히는 필드 전부 (`:232-240`) |

세부 결정:

- **구분자는 `U+001F`(Unit Separator)** (`:193-195`). 사용자 입력에 절대 나타나지 않는
  제어문자라 필드 경계가 뭉개지지 않고(`"김유"+"엠"` ≠ `"김"+"유엠"`) 이스케이프도 필요 없다.
  회귀: `BusinessCardSnapshotTests.swift:94-101`.
- **`Hasher`/`hashValue` 금지** (`:185`). 프로세스마다 시드가 달라 디스크 키로 못 쓴다 —
  앱을 재시작할 때마다 전량 미스가 된다. 회귀: `BusinessCardSnapshotTests.swift:34-45`.
- **색상 스킴은 선제적으로 넣었다** (`:226-231`). 지금 구워지는 픽셀 자체는 스킴과 무관하다 —
  카드 면은 시드 RGB 리터럴(`BusinessCardSnapshotComposer.swift:73`)에 검정 단색 텍스트
  (`:101`), 배경은 투명이다. 하지만 #1248 템플릿이 DS 토큰을 하나라도 쓰는 순간
  `UIColor(Color)` 해석이 **굽는 시점의 트레잇으로 고정**되고, 그 결과가 디스크에 30일 남는다.
  앱 버전으로만 무효화되니 릴리스 전까지 자가 치유되지 않는다 — 키 한 줄 넣는 비용이 그때
  디버깅하는 비용보다 싸다. 이 트레잇 읽기 때문에 `key(for:)`/`cached(for:)` 의 `nonisolated`
  가 빠져 둘 다 MainActor 이고, 초깃값 조회를 하는 셀 `init(card:)` 도
  `@MainActor` 다(`ReceivedCardSnapshotCell.swift:39-43`).
- **`partAPIValue` 이지 `part` 열거형이 아니다** (`:235-236`). 우리가 못 읽은 파트(`partRaw`)도
  키에서 구분되어야 한다.
- **`generation` 은 `String` 그대로** (`:237-238`). 절대 규칙 #2 — 서버 정수는 Int 변환 없이 쓴다.
- **`displayName` 같은 파생 값이 아니라 `name`·`nickname` 원본 필드** (`:220-222`).
  그 computed property 를 #1247/#1248 이 각자 추가 중이라 셋째 사본을 만들지 않는다.

**키에 넣지 않은 것**: `exchangedAt` · `exchangeContext` · `exchangeMethod` · `ReceivedCard.id` ·
링크 4종(email/github/linkedIn/blog) (`:187-188`). 앞면 픽셀에 찍히지 않으므로 넣으면 의미 없는
재생성만 는다. 부수 효과로 같은 사람 명함을 두 경로로 받아도 파일 하나를 공유한다.
회귀: `BusinessCardSnapshotTests.swift:69-92`.

## 무효화 매트릭스

| 무엇이 바뀌면 | 무엇이 일어나나 | 메커니즘 |
|--------------|----------------|---------|
| 앱 버전(릴리스) | 전량 재굽기 | 버전이 키 컴포넌트 (`:197-214`) |
| DEBUG 재컴파일 | 전량 재굽기 | 실행 파일 수정 시각이 키 컴포넌트 (`:203-213`) — 「알려진 한계」 참고 |
| 앞면 필드(이름·파트·기수·학교·`avatarURL` 등) | 그 카드만 재굽기 | 필드가 키 컴포넌트 (`:232-240`) |
| `Metrics.snapshotPixelSize` | 전량 재굽기 | 픽셀 크기가 키 컴포넌트 (`:225`) |
| 색상 스킴 전환 | 새 스킴에서 처음 보는 카드만 재굽기 (반대 스킴 분량은 참조 없이 남았다가 TTL·LRU 로 소멸) | 트레잇이 키 컴포넌트 (`:226-231`) — 지금은 잠복, #1248 대비 선제. 「캐시 키」 세부 결정 참고 |
| 계정 전환 | 디스크·메모리 전량 삭제 + `failedKeys` 리셋. 단 저장된 소유자가 없으면 「최초 진입」으로 보고 소유자만 기록하고 지우지 않는다 | `purgeIfOwnerChanged` (`:139-157`, 최초 진입 가드 `:150-152`) — 아래 참고 |
| `avatarURL` 은 같은데 그 URL 의 원본 사진만 교체 | **아무것도** — 콘텐츠 키로 못 잡는 유일한 구멍 | 30일 절대 TTL 이 스테일 상한 (`:60-62`) |

- **계정 전환이 유일한 명령형 삭제**이고, 이것도 공개 API 가 아니라 그리드 진입 시 자동으로
  도는 가드다(`:97`, `:166-172`). 지우는 이유는 화면 노출이 아니라(목록 자체가 `ownerMemberId`
  로 격리됨, #1217) **디스크에 남는 바이트**다 — 스냅샷에는 이전 사용자가 받은 사람의
  이름·학교·파트가 그려져 있다(`:129-136`). 로그아웃 즉시가 아니라 다음 그리드 진입 때 지우는
  이유: `NetworkClient.logout()` 훅은 CoreNetwork → Feature 역방향 의존을 만든다(`:135-136`).
  마지막 소유자 기록은 **디바이스 스코프**다 — `sessionScopedKeys` 에 넣으면 로그아웃 때 같이
  지워져 「이전 소유자」를 잊고 purge 를 건너뛴다(`:71-74`). 저장값 `nil` 은 「계정이 바뀐 것」이
  아니라 「이 기기 최초 진입」이라 신규 설치마다 빈 캐시를 비우는 헛 IO 를 돌리지 않는다
  (`:150-152`). 회귀: `BusinessCardSnapshotTests.swift:160-183`.
- 마지막 행이 이 설계의 의도된 트레이드오프다. URL 불변 조건이 서버에서 보장되지 않는 한 콘텐츠
  키만으로는 못 잡고, 이를 잡자고 ETag 조회나 클리어 API 를 붙이면 굽기 경로에 네트워크가 낀다.
  30일이 상한이면 충분하다고 판단했다.

## 메모리·디스크 상한

전부 `BusinessCardSnapshotProvider.Metrics` 한 곳에 있다(`:44-67`). 설정이 설계값에서 흘러내리지
않는 것은 `BusinessCardSnapshotTests.swift:138-158` 이 지킨다.

| 상수 | 값 | 근거 |
|------|-----|------|
| `snapshotPixelSize` | 512 × 288 | 카드 비 1.8(512 / 1.8 ≈ 288). 그리드 셀 실측 폭 181pt → 유효 배율 2.83x 라 @3x 에서도 선명. 정사각 512² 처럼 픽셀의 44% 를 letterbox 로 버리지 않는다 (`:47-50`) |
| `memoryLimit` | 12MB | 장당 디코드 512 × 288 × 4B = 589,824B ≈ 590KB → **≈ 20장**. 2열 그리드 한 화면이 8칸이라 되돌려 스크롤해도 히트하는 두 화면 반 분량. 장당 크기가 고정이라 cost 상한이 곧 장수 상한 — `countLimit` 은 따로 두지 않는다 (`:52-54`) |
| `diskLimit` | 20MB | 장당 PNG 30~40KB → 500장 이상. 초과 시 Kingfisher 가 마지막 접근이 오래된 것부터 상한 절반까지 트리밍 — 자주 여는 명함이 남는다 (`:56-58`) |
| `diskExpiration` | `.days(30)` **절대** TTL | 조회로 연장하지 않는다(`:102-106` 의 `.diskCacheAccessExtendingExpiration(.none)`). `avatarURL` 구멍의 스테일 상한을 유한하게 만드는 유일한 장치 (`:60-62`) |
| 저장 위치 | `Library/Caches/umc.businesscard.snapshot` | 스냅샷은 SwiftData 명함첩에서 언제든 재생성 가능한 **파생물** — 백업 대상(`Application Support`)에 두면 사용자 백업 용량을 먹는다 (`:25-36`) |

## 생성 시점 — 지연 생성만

프리페치·워밍업 API 는 **없다.** 굽기 진입점은 셀이 화면에 정착했을 때 하나뿐이다.

1. 셀 `init` 이 메모리 캐시를 **동기** 조회해 초깃값으로 넣는다
   (`ReceivedCardSnapshotCell.swift:39-43`). NSCache 조회는 마이크로초 단위라 스크롤 중 셀
   생성에도 안전하고, 되돌아 스크롤할 때 2D 셀이 한 프레임 스치는 깜빡임이 없다.
   스크롤 경로에서 도는 스냅샷 코드는 이것이 유일하다(`BusinessCardSnapshotProvider.swift:79-85`).
2. 미스면 `.task(id: 캐시 키, priority: .utility)` 가 **120ms 정착 지연** 후 굽기를 시작한다
   (`ReceivedCardSnapshotCell.swift:74-76`, `:84-93`, `Metrics.settleDelay` `:64-66`). 플링 중
   스쳐 지나가는 셀은 `LazyVGrid` 가 뷰를 제거하며 task 를 취소하므로 120ms 를 못 넘기고
   사라진다 — 굽기가 시작조차 안 되니 스크롤 프레임에 90ms 짜리 렌더가 실릴 경로가 없다.
   접근성 텍스트 크기(`dynamicTypeSize.isAccessibilitySize`)면 **굽기 자체를 건너뛴다**(`:87`) —
   보이지도 않을 이미지에 렌더 비용을 태우지 않는다(「알려진 한계」 참고).
3. 굽는 동안·실패 시 폴백은 스피너가 아니라 **완성된 2D `ReceivedCardCell`** 이다
   (`ReceivedCardSnapshotCell.swift:12-17`). 이름·학교·파트·기수·아바타가 전부 있어 정보 손실이
   0 이고, 3D 가 영구 실패해도 화면이 성립한다. VoiceOver 라벨도 2D 셀과 같은 문자열이다(`:64-67`).

폴백과 스냅샷은 `if/else` 교체가 아니라 `ZStack` 이다(`ReceivedCardSnapshotCell.swift:47-63`).
`ReceivedCardCell` 이 `opacity` 로 항상 깔려 **레이아웃을 결정하는 사이징 레이어**이고, 스냅샷은
그 위에 얹힐 뿐이다. 스냅샷 쪽에 `minHeight` 상수 사본을 두면 폴백의 바닥값과 사람 손으로
맞춰져야 하고 — 폴백은 글자가 커지면 늘어나는데 상수는 그대로라 Dynamic Type 마다 어긋나고,
셀마다 굽기 완료 시점이 달라 스크롤 중 행 높이가 제각각 줄어든다(`:49-52`). 이 구조 덕에 모든
텍스트 크기에서 폴백↔스냅샷 높이가 자동 일치하고 상수 사본이 없다.

경계 처리:

- **취소는 실패가 아니다.** `CancellationError` 는 실패 기억에 넣지 않는다 — 셀이 다시 보이면
  다시 굽는다(`BusinessCardSnapshotProvider.swift:120-122`). 렌더러도 합성 직후, GPU 가 돌기
  전이 취소를 볼 수 있는 마지막 값싼 지점이라 거기서 한 번 더 확인한다
  (`BusinessCardSnapshotRenderer.swift:72-73`).
- **항구적 실패는 프로세스 동안 기억한다.** Metal 디바이스 없음·템플릿 손상 같은 환경 실패에서
  셀이 보일 때마다 90ms 를 다시 태우지 않는다(`failedKeys`, `:38-42`). 디스크에 남기지 않아 앱
  재시작 시 한 번 더 시도한다 — 실패를 영구화하지 않는다.
  회귀: `BusinessCardSnapshotTests.swift:273-289`.
- 실패는 사용자에게 보이지 않으므로 `BusinessCardSnapshotError` 는 메시지가 없고 `ErrorHandler`
  전역 Alert 로 올리지 않는다(`BusinessCardSnapshotRenderer.swift:199-207`).

프리페치를 안 둔 이유: 수신 직후 배치 굽기(20장 ≈ 0.74s)는 가능하지만, 지연 생성 + 2계층
캐시만으로 이미 첫 스크롤부터 폴백이 완성된 화면을 주고 두 번째 진입부터는 디스크 히트(0.34ms)다.
호출 시점 관리가 필요한 API 를 하나 늘릴 이유가 실측에 없다. 스파이크가 지목한 RealityKit
첫 초기화 워밍업은 3D 상세 화면(#1247) 소관이고, 그리드는 폴백 덕에 워밍업 없이도 성립한다.

## 성능 실측

**iPhone 17 Pro 시뮬레이터 · Debug 구성 (리뷰 반영 후 재측정). 실기기는 미측정이다.**

| 측정 | 값 |
|------|-----|
| ① 첫 굽기 | 32.1ms |
| ② 웜 1장(다른 카드) 512×288 | 8.2ms · 불투명 픽셀 83.9% |
| ③ 20장 배치 | 총 739.5ms · 장당 37.0ms |
| ④ 메모리 히트 1000회 평균 | 2.63µs (프레임 예산 16.7ms 대비 6,348배 여유) |
| ⑤ 디스크 히트 1장 | 0.34ms |
| ⑥ 20장 저장 후 메모리 증가 | 10,512KB (상한 12MB) |

①은 같은 프로세스에서 스파이크 스위트가 먼저 도는지에 따라 32ms~182ms 로 흔들린다. 어느 쪽이든
**실기기 첫 실행 근거로 읽으면 안 된다** — 시뮬레이터 Metal 셰이더 캐시가 호스트에 남아 있어
이미 웜인 상태의 수치다. RealityKit 최초 초기화의 진짜 비용은 스파이크가 잰
9.42~11.62s(역시 시뮬레이터) 쪽이고, 그 격차 자체가 증거다. 실기기 재측정 조건은 스파이크 문서
「첫 진입 비용」에 있다.

재현:

    cd UMCApp && make test SCHEME=BusinessCardPresentation 2>&1 | grep "SNAPSHOT#1249"

기본 `make test`(`SCHEME=UMCApp`) 로는 돌지 않는다 — 앱 스킴 테스트 액션에
`BusinessCardPresentationTests` 가 없다. 스위트는 스파이크와 같은 이유로 `.serialized` 다
(메모리 증가분이 프로세스 전역 `phys_footprint` 차이, `BusinessCardSnapshotTests.swift:24-25`).
측정용 키는 실행마다 `runSalt` 로 갈린다 — 고정 키면 두 번째 실행부터 굽기가 아니라 디스크
히트를 재게 된다(`:302-304`).

## #1248 머지 후 교체 지점 3곳

지금의 합성기는 스파이크 프리미티브(`generateBox` + 텍스트 메시 3줄)를 제품 경로로 올린
임시물이다. `BusinessCardComposer`(#1248)와 USDZ 템플릿(#1246)이 오면 아래 3곳만 바꾼다.

| # | 위치 | 무엇을 |
|---|------|--------|
| 1 | `BusinessCardSnapshotRenderer.swift:34` | `defaultComposing` 의 `BusinessCardSnapshotComposer.compose` → `BusinessCardComposer.compose` 로 교체. 시그니처는 `BusinessCardEntityComposing`(`:17-18`) 함수 타입 seam 이라 이 한 줄이 전부다 |
| 2 | `BusinessCardSnapshotProvider.swift:114` | `snapshot(for:)` 의 `portrait: nil` 을 `RemoteImageLoader` 로 받은 아바타 `CGImage` 로 채움 (`:113` 주석) |
| 3 | `BusinessCardSnapshotComposer.swift` | **파일 통째 삭제** — 헤더 주석(`:16`)에 명시된 계약 |

`compose:` 파라미터는 `BusinessCardEntityComposing? = nil` 옵셔널이다
(`BusinessCardSnapshotProvider.swift:95`, `BusinessCardSnapshotRenderer.swift:62`) — MainActor 인
`defaultComposing` 을 기본 인자로 두면 기본 인자 표현식이 호출자 격리로 평가돼 Swift 6 언어
모드에서 에러라서다. `nil` 해소는 `render` 본문 한 곳(`BusinessCardSnapshotRenderer.swift:71`)
에서만 일어나므로 교체 지점은 여전히 1곳이다.

임시 합성기의 텍스트는 검정이다(`BusinessCardSnapshotComposer.swift:101`) —
`ReceivedCardCell.swift:149-154` 의 실측(시드 배경 + 흰 라벨은 8개 파트 전부 WCAG AA 미달,
최악 1.42:1 / 검정 라벨은 5.60~14.77:1 로 전부 통과)이 근거다.
**#1248 템플릿의 수용 기준: 앞면 텍스트 대비 AA 4.5:1 이상.**

마이그레이션 코드는 필요 없다. 앱 버전이 캐시 키에 있어 옛 스냅샷은 릴리스와 함께 자동
무효화된다(`BusinessCardSnapshotRenderer.swift:30-33`). 카메라 프레이밍도 엔티티 바운즈에서
역산하므로(`:105-126`) USDZ 템플릿으로 카드 치수가 달라져도 렌더러는 그대로 산다.

## 알려진 한계

- **DEBUG 빌드마다 전량 재굽기.** 실행 파일 수정 시각이 키에 들어가서 재컴파일 = 전량 미스다
  (`BusinessCardSnapshotProvider.swift:203-213`). 「템플릿을 고쳤는데 옛 이미지가 남는」 함정을
  없애는 대가이고, 개발 중 그리드 첫 진입이 매번 콜드인 이유다. 릴리스에는 해당 없다.
- **Dynamic Type — 접근성 크기(AX1~AX5)에서는 스냅샷을 아예 쓰지 않는다.** 비트맵은 텍스트 크기
  설정을 못 따라가므로(이름 11.1pt / 부가정보 7.8pt 로 고정) 폴백 2D 셀을 유지하고 굽기 자체를
  건너뛴다(`ReceivedCardSnapshotCell.swift:87`, `:99-101`). 남는 진짜 한계는 둘이다:
  - 비접근성 구간(Large~xxxLarge)에서는 구운 글자가 커지지 않는다.
  - AX 크기에서 일반 크기로 되돌려도 그 셀은 화면 밖으로 나갔다 들어오기 전까지 폴백을
    유지한다 — task id 에 텍스트 크기가 없어서인데, 텍스트 크기 변경마다 전 셀 재굽기가 도는
    것을 피하려는 의도적 선택이다.
- **`avatarURL` 불변 사진 교체는 못 잡는다.** 30일 절대 TTL 이 상한 — 「무효화 매트릭스」 참고.
- **셀 종횡비 1.46(실측 181×124pt)과 카드 종횡비 1.8 이 충돌한다.** 스냅샷이 셀 안에서
  레터박스되고, 카드 그림이 폴백보다 세로로 작게 보인다. 해소하려면 그리드 셀 높이 ·
  렌더 `pixelSize` · 카드 면 소유 주체 중 하나를 디자인팀이 결정해야 한다 — 이번 PR 범위 밖.
- **구워진 앞면에 닉네임·학교·아바타가 없다.** 임시 합성기는 이름·파트·기수 3줄만 그린다
  (`BusinessCardSnapshotComposer.swift:77`). 폴백은 전부 보여주므로 폴백→스냅샷 전환이
  정보 손실 전환이다. **#1248 수용 기준: 구워진 앞면의 표시 항목 ⊇ `ReceivedCardCell` 표시 항목.**
- **동시 굽기 제한이 없다.** 초기 진입 시 화면의 8칸이 거의 동시에 정착해 MainActor 렌더가
  몰릴 수 있다. 측정(③)은 순차 20장 기준이라 이 버스트를 재현하지 않는다.
- **`failedKeys` 가 캐시 인스턴스가 아니라 모듈 전역이다.** `purgeIfOwnerChanged(owner:in:cache:)`
  가 캐시를 주입받으면서도 전역 `failedKeys` 를 비운다(`BusinessCardSnapshotProvider.swift:42`,
  `:155`). 지금은 테스트가 `.serialized` 라 무해하지만 격리 계약이 절반만 성립한다.
- **iPad 등 넓은 폭.** `columnCount` 가 2 고정이라(`ReceivedCardsView.swift:38`) 셀 폭이 커지면
  512px 원본이 업스케일된다.
- **렌더 타깃이 `.rgba8Unorm`(비-sRGB)인데 `CGColorSpaceCreateDeviceRGB()` 로 해석한다**
  (`BusinessCardSnapshotRenderer.swift:133`, `:181`). 감마 왕복이 어긋나면 구운 시드 컬러가
  같은 화면의 폴백 칩과 미세하게 다를 수 있다. 육안/픽셀 대조 미검증.

## 코드 위치

| 파일 | 역할 |
|------|------|
| `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardSnapshotProvider.swift` | 단일 진입점 — 키 구성 · 2계층 캐시 · 소유자 purge · 실패 기억 |
| `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardSnapshotRenderer.swift` | `RealityRenderer` 오프스크린 렌더 · 합성기 seam · 카메라 프레이밍 |
| `UMCApp/Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardSnapshotComposer.swift` | 임시 프리미티브 합성기 — **#1248 머지 시 삭제** |
| `UMCApp/Features/BusinessCard/Presentation/Sources/Components/ReceivedCardSnapshotCell.swift` | 그리드 셀 — 지연 생성 · 정착 지연 · 2D 폴백(사이징 레이어) |
| `UMCApp/Features/BusinessCard/Presentation/Tests/BusinessCardSnapshotTests.swift` | 회귀 + 측정 러너 (`SNAPSHOT#1249` 로그) |
