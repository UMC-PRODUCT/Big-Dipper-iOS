import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Home",
    domainExtraDependencies: [
        // 최근 공지(#915)가 NoticeDomain의 조회 파이프라인(NoticeItemModel/NoticeListRequest 등)을 재사용한다.
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
    ],
    dataExtraDependencies: [
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    // staticFramework의 Compile Sources 산출물(.mlmodelc)은 소비 타겟까지 전파되지 않으므로,
    // 런타임 로드가 가능하도록 리소스 번들로도 명시한다 (ScheduleClassifierRepository 참고).
    dataResources: [
        "Data/Sources/MLModels/**",
    ],
    presentationExtraDependencies: [
        // 홈 진입 시 앱스토어 리뷰 요청(requestReview) 환경 값 사용.
        .sdk(name: "StoreKit", type: .framework),
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .external(name: "Moya"),
        .target(name: "HomeDomain"),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
