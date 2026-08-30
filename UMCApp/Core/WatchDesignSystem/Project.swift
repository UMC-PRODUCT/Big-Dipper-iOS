import ProjectDescription
import ProjectDescriptionHelpers

// watchOS 디자인 시스템을 CoreDesignSystem 에 합치지 않고 별도 모듈로 둔 이유.
//
// 1) 토큰 값이 다르다. CoreDesignSystem 의 Colors.xcassets 는 colorset 마다 light/dark 를
//    따로 갖는데 watchOS 는 항상 dark 로 해석한다. 같은 카탈로그를 워치에 링크하면
//    indigo500 이 스펙값 #4869F0 이 아니라 dark 값 #4264F0 으로 나온다(orange500 → #FF6C0F,
//    grey400 → #7C8792 도 마찬가지). 그래서 이 모듈은 asset catalog 없이 sRGB 리터럴을 쓴다.
// 2) 타이포가 다르다. 워치 스펙은 시스템 폰트(SF) 기반이라 Pretendard(.otf 3종)가 필요 없다.
//    CoreDesignSystem 을 링크하면 쓰지도 않는 폰트 리소스가 워치 앱 번들에 실린다.
// 3) 컴포넌트 규칙이 반대다. iOS 는 Glass 를 카드 배경까지 쓰지만 워치는 컨트롤/오버레이에만
//    쓰고 콘텐츠 배경은 OLED 순수 블랙 + 불투명 solid 로 간다(가독성·배터리·번인).
//    한 모듈에 두면 44pt 고정 높이 버튼처럼 워치에서 쓰면 안 되는 API 가 그대로 자동완성에 뜬다.
//
// destinations 에 .iPhone 을 함께 넣은 것은 순전히 테스트 실행 경로 때문이다. Makefile 기본
// DESTINATION 이 iOS 시뮬레이터라, 워치 전용으로 잡으면 `make test SCHEME=CoreWatchDesignSystem`
// 이 기본값으로 돌지 않는다. 이 모듈은 watchOS 전용 API 를 쓰지 않아 iOS 에서도 그대로 컴파일된다.
// 멀티플랫폼 Core 모듈 선례는 Core/WatchConnectivity 에 이미 있다.
// iOS 화면은 이 모듈을 쓰지 않는다 — CoreDesignSystem 을 쓴다. 의존하는 건 UMCWatchApp 뿐이다.
let project = coreProject(
    name: "CoreWatchDesignSystem",
    bundleIdSuffix: "watchdesignsystem",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    dependencies: [],
    includesTests: true
)
