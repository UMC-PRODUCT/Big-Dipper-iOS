import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "UMCApp",
    settings: recommendedProjectSettings,
    targets: [
        .target(
            name: "UMCApp",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.UMCApp",
            deploymentTargets: .iOS("26.4"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "NSBluetoothAlwaysUsageDescription": "주변 명함을 교환하기 위해 블루투스를 사용합니다.",
                    "NSBluetoothPeripheralUsageDescription": "주변 명함을 교환하기 위해 블루투스를 사용합니다.",
                    "NFCReaderUsageDescription": "NFC로 명함 정보를 주고받습니다.",
                    "NSNearbyInteractionUsageDescription": "근거리에서 정확한 명함 교환을 위해 위치를 사용합니다.",
                    // Secrets/Shared.xcconfig(+ Secrets.xcconfig)에서 주입되는 값.
                    // UMCFoundation의 Config가 이 키들을 읽는다. (BASE_URL / KAKAO_KEY / TMAP_SECRET_KEY)
                    "BASE_URL": "$(BASE_URL)",
                    "KAKAO_KEY": "$(KAKAO_KEY)",
                    "TMAP_SECRET_KEY": "$(TMAP_SECRET_KEY)",
                    // Kakao SDK 인증 리다이렉트용 URL Scheme (AuthConfig.kakaoURLScheme와 동일 규칙)
                    "CFBundleURLTypes": [
                        [
                            "CFBundleURLSchemes": ["kakao$(KAKAO_KEY)"],
                        ],
                    ],
                    "LSApplicationQueriesSchemes": ["kakaokompassauth", "kakaolink"],
                ]
            ),
            buildableFolders: [
                "UMCApp/Sources",
                "UMCApp/Resources",
            ],
            entitlements: .file(path: "UMCApp.entitlements"),
            dependencies: [
                .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
                .project(target: "AuthPresentation", path: .relativeToRoot("Features/Auth")),
                .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
                .project(target: "NoticePresentation", path: .relativeToRoot("Features/Notice")),
                .project(target: "NoticeData", path: .relativeToRoot("Features/Notice")),
                .project(target: "ActivityPresentation", path: .relativeToRoot("Features/Activity")),
                .project(target: "HomePresentation", path: .relativeToRoot("Features/Home")),
                .project(target: "CommunityPresentation", path: .relativeToRoot("Features/Community")),
                .project(target: "MyPagePresentation", path: .relativeToRoot("Features/MyPage")),
                .project(target: "BadgePresentation", path: .relativeToRoot("Features/Badge")),
                .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
                .project(target: "UMCAppWidget", path: "UMCAppWidget"),
                .project(target: "UMCWatchApp", path: "UMCWatchApp"),
            ],
            settings: .settings(
                configurations: [
                    .debug(name: .debug, xcconfig: "Secrets/Shared.xcconfig"),
                    .release(name: .release, xcconfig: "Secrets/Shared.xcconfig"),
                ]
            )
        ),
        .target(
            name: "UMCAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.UMCAppTests",
            deploymentTargets: .iOS("26.4"),
            infoPlist: .default,
            buildableFolders: [
                "UMCApp/Tests",
            ],
            dependencies: [.target(name: "UMCApp")]
        ),
    ]
)
