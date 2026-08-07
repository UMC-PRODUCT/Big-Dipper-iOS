import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Notice",
    presentationExtraDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        // `UserSessionManager`(#957 후속으로 CoreDomain에 승격)를 사용한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .target(name: "NoticeDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ])
