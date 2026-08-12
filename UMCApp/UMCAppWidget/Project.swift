import ProjectDescription
import ProjectDescriptionHelpers

let project = widgetExtensionProject(
    name: "UMCAppWidget",
    bundleId: "com.umc.product.widget",
    entitlements: .file(path: "UMCAppWidget.entitlements"),
    dependencies: [
        .project(target: "CoreWidgetShared", path: .relativeToRoot("Core/WidgetShared")),
    ]
)
