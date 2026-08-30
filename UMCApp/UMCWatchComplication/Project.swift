import ProjectDescription
import ProjectDescriptionHelpers

// 번들 ID 는 반드시 워치 앱 번들 ID 를 prefix 로 가져야 한다. 어긋나면 워치 앱이 익스텐션을
// 임베드하지 못하고 업로드가 거부된다.
let project = widgetExtensionProject(
    name: "UMCWatchComplication",
    bundleId: "com.umc.product.watchkitapp.complication",
    destinations: [.appleWatch],
    deploymentTargets: .watchOS("26.4"),
    entitlements: .file(path: "UMCWatchComplication.entitlements"),
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
        .project(target: "CoreWatchDesignSystem", path: .relativeToRoot("Core/WatchDesignSystem")),
    ]
)
