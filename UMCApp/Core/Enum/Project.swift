import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreEnum",
    bundleIdSuffix: "enum",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
