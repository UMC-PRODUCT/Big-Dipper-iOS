import ProjectDescription
import ProjectDescriptionHelpers

let project = widgetExtensionProject(
    name: "UMCAppWidget",
    bundleId: "dev.tuist.UMCApp.widget",
    entitlements: .file(path: "UMCAppWidget.entitlements"),
    dependencies: [
        .project(target: "CoreWidgetShared", path: .relativeToRoot("Core/WidgetShared")),
    ]
)
