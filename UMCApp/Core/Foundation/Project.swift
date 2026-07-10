import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "UMCFoundation",
    bundleIdSuffix: "foundation",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    includesTests: true
)

