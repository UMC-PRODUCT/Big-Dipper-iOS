import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreNetwork",
    bundleIdSuffix: "network",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .external(name: "Moya"),
    ]
)
