import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreDI",
    bundleIdSuffix: "di",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesTests: true
)
