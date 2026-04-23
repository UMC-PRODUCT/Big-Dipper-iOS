import ProjectDescription

let project = Project(
    name: "UMCApp",
    targets: [
        .target(
            name: "UMCApp",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.UMCApp",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            buildableFolders: [
                "UMCApp/Sources",
                "UMCApp/Resources",
            ],
            dependencies: [
                .project(target: "AuthPresentation", path: .relativeToRoot("Features/Auth")),
                .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
                .project(target: "NoticePresentation", path: .relativeToRoot("Features/Notice")),
                .project(target: "ActivityPresentation", path: .relativeToRoot("Features/Activity")),
                .project(target: "HomePresentation", path: .relativeToRoot("Features/Home")),
                .project(target: "CommunityPresentation", path: .relativeToRoot("Features/Community")),
                .project(target: "MyPagePresentation", path: .relativeToRoot("Features/MyPage")),
            ]
        ),
        .target(
            name: "UMCAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.UMCAppTests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            buildableFolders: [
                "UMCApp/Tests",
            ],
            dependencies: [.target(name: "UMCApp")]
        ),
    ]
)
