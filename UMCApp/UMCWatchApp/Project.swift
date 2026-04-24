import ProjectDescription
import ProjectDescriptionHelpers

let project = watchAppProject(
    name: "UMCWatchApp",
    bundleId: "dev.umc.appproduct.watchkitapp",
    entitlements: .file(path: "UMCWatchApp.entitlements"),
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
    ]
)
