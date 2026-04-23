import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreWidgetShared",
    bundleIdSuffix: "widgetshared",
    dependencies: [
        .sdk(name: "WidgetKit", type: .framework, status: .required),
    ]
)
