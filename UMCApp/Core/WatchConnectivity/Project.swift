import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreWatchConnectivity",
    bundleIdSuffix: "watchconnectivity",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    dependencies: [
        .sdk(name: "WatchConnectivity", type: .framework, status: .required),
    ],
    includesTests: true
)
