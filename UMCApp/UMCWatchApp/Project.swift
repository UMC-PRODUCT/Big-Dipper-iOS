import ProjectDescription
import ProjectDescriptionHelpers

let project = watchAppProject(
    name: "UMCWatchApp",
    bundleId: "com.umc.product.watchkitapp",
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
        .project(target: "CoreWatchDesignSystem", path: .relativeToRoot("Core/WatchDesignSystem")),
        // Loadable·AppError 재사용. UMCFoundation 은 이미 watchOS destination 을 선언하고
        // 있어(Core/Foundation/Project.swift) 워치 전용 상태 타입을 새로 만들 이유가 없다.
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesTests: true
)
