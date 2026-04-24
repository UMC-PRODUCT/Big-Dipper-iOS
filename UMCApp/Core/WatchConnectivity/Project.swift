import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreWatchConnectivity",
    bundleIdSuffix: "watchconnectivity",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.3", watchOS: "26.3"),
    dependencies: [
        .sdk(name: "WatchConnectivity", type: .framework, status: .required),
    ]
)
