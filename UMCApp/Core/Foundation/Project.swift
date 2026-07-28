import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "UMCFoundation",
    bundleIdSuffix: "foundation",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    dependencies: [
        // LocationManager: 위치 갱신/역지오코딩(MKReverseGeocodingRequest)/지오펜스 모니터링.
        .sdk(name: "CoreLocation", type: .framework),
        .sdk(name: "MapKit", type: .framework),
    ],
    includesTests: true
)

