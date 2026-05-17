import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "MyPage",
    domainExtraDependencies: [
        .project(target: "CoreEnum", path: .relativeToRoot("Core/Enum")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    dataExtraDependencies: [
        .project(target: "CoreEnum", path: .relativeToRoot("Core/Enum")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        .project(target: "BadgeDomain", path: .relativeToRoot("Features/Badge")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .target(name: "MyPageDomain"),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation"))
    ]
)
