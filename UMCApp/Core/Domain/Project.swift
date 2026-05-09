import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreDomain",
    bundleIdSuffix: "domain",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreEnum", path: .relativeToRoot("Core/Enum")),
    ]
)
