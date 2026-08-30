import ProjectDescription
import ProjectDescriptionHelpers

// `.project(target:)` 로 appExtension 을 걸면 Tuist 가 워치 앱 PlugIns 에 자동 임베드한다.
let project = watchAppProject(
    name: "UMCWatchApp",
    bundleId: "com.umc.product.watchkitapp",
    entitlements: .file(path: "UMCWatchApp.entitlements"),
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
        .project(target: "CoreWatchDesignSystem", path: .relativeToRoot("Core/WatchDesignSystem")),
        .project(target: "UMCWatchComplication", path: .relativeToRoot("UMCWatchComplication")),
    ]
)
