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
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
    ],
    // Data 테스트 타겟은 Data/Tests 디렉터리가 생기는 시점(이슈 #1195)에 켠다 —
    // Tuist는 존재하지 않는 소스 글롭을 에러로 막는다.
    includesDataTests: false,
    dataTestDependencies: [
        .target(name: "BusinessCardDomain"),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ]
)
