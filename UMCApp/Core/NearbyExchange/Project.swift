import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "CoreNearbyExchange",
    settings: recommendedProjectSettings,
    targets: [
        .target(
            name: "CoreNearbyExchange",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "dev.umc.core.nearbyexchange",
            deploymentTargets: .iOS("26.4"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
                .sdk(name: "CoreBluetooth", type: .framework, status: .required),
                .sdk(name: "CoreNFC", type: .framework, status: .required),
                .sdk(name: "NearbyInteraction", type: .framework, status: .required),
                .sdk(name: "ARKit", type: .framework, status: .required),
                .sdk(name: "RealityKit", type: .framework, status: .required),
                .sdk(name: "WiFiAware", type: .framework, status: .required),
            ]
        ),
        .target(
            name: "CoreNearbyExchangeTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.umc.core.nearbyexchange.tests",
            deploymentTargets: .iOS("26.4"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "CoreNearbyExchange"),
            ]
        ),
    ]
)
