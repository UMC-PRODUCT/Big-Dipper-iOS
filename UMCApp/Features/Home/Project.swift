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
    presentationExtraDependencies: [
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
