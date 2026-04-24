import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "UMCFoundation",
    bundleIdSuffix: "foundation",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.3", watchOS: "26.3")
)

