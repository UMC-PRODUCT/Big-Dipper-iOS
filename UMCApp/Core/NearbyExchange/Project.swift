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
                // MultipeerConnectivity(MPCTransport)는 자동 링크. NI는 거리 측정
                // (PeerRangingCoordinator) 전용 — transport가 아니다.
                .sdk(name: "NearbyInteraction", type: .framework, status: .required),
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
