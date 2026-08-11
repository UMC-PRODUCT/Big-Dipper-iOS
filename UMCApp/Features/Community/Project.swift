import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Community",
    presentationExtraDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreRouting", path: .relativeToRoot("Core/Routing")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .target(name: "CommunityDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        .target(name: "CommunityDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
