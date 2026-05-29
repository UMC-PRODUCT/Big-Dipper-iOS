import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreUIComponents",
    bundleIdSuffix: "uicomponents",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
        .external(name: "Kingfisher"),
    ]
)
