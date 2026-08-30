import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "BusinessCard",
    domainExtraDependencies: [
        // ExchangeCardsUseCase가 NearbyTransportProtocol·ExchangePayload를 소비한다.
        .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
    ],
    dataExtraDependencies: [
        // 정본 프로필(Profile) 위임·매핑.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    presentationExtraDependencies: [
        // BusinessCardUseCaseProvider가 NearbyTransportProtocol을 직접 import한다.
        // 전이 의존에 기대지 않고 import하는 모듈을 명시 선언하는 게 이 레포 규약
        // (선례: Features/Community/Project.swift, Features/Auth/Project.swift).
        .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        // 명함첩 그리드의 2D 스냅샷 캐시가 Kingfisher `ImageCache` 를 직접 쓴다 (#1249).
        // CoreUIComponents 가 이미 링크하지만 전이 의존에 기대지 않는다 (위 규약).
        .external(name: "Kingfisher"),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        // Router 계약 테스트가 Moya.Task 케이스를 직접 검사한다 (Activity 선례).
        .external(name: "Moya"),
        .target(name: "BusinessCardDomain"),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        // ViewModel 테스트가 ReceivedCard·MyCard 와 Loadable·ErrorHandler 를 직접 만든다.
        .target(name: "BusinessCardDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        // 교환 세션 테스트가 DiscoveredPeer·NearbyError 를 직접 만든다.
        .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
        // 스냅샷 테스트가 ImageCache 를 직접 만들어 상한·트리밍을 검사한다 (#1249).
        .external(name: "Kingfisher"),
    ]
)
