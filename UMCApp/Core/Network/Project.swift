import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreNetwork",
    bundleIdSuffix: "network",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .external(name: "Moya"),
        .external(name: "KakaoSDKAuth"),
        .external(name: "KakaoSDKCommon"),
        .external(name: "KakaoSDKUser"),
        .external(name: "KakaoSDKTalk"),
        .external(name: "GoogleSignIn"),
        .sdk(name: "Security", type: .framework),
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    testEntitlements: "Tests/CoreNetworkTests.entitlements"
)
