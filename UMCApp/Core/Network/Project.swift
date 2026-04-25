import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreNetwork",
    bundleIdSuffix: "network",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .external(name: "Moya"),
        .sdk(name: "Security", type: .framework),
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
