import ProjectDescription
import ProjectDescriptionHelpers

let project = watchAppProject(
    name: "UMCWatchApp",
    bundleId: "com.umc.product.watchkitapp",
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
    ]
)
