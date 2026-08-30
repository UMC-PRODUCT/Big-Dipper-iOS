import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreDomain",
    bundleIdSuffix: "domain",
    // #1212: watch 출석 도메인이 ActivityDomain → CoreDomain 경로로 canonical 모델을 재사용한다.
    // 소스는 Foundation/UMCFoundation 만 쓰므로 watchOS 제약이 없다.
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
