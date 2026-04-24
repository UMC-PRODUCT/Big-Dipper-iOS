import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "CoreNearbyExchange",
    targets: [
        .target(
            name: "CoreNearbyExchange",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "dev.umc.core.nearbyexchange",
            deploymentTargets: .iOS("26.3"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
                .sdk(name: "CoreBluetooth", type: .framework, status: .required),
                .sdk(name: "CoreNFC", type: .framework, status: .required),
                .sdk(name: "NearbyInteraction", type: .framework, status: .required),
                .sdk(name: "ARKit", type: .framework, status: .required),
                .sdk(name: "RealityKit", type: .framework, status: .required),
            ]
        )
    ]
)
