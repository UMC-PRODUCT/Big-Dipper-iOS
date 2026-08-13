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
            // App Store에 등록된 기존 앱 레코드와 동일해야 한다. 이 값이 바뀌면 별개 앱이 되어
            // 기존 카카오/Firebase/Google OAuth 등록이 전부 무효화된다.
            bundleId: "com.umc.product",
            deploymentTargets: .iOS("26.4"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "NSBluetoothAlwaysUsageDescription": "주변 명함을 교환하기 위해 블루투스를 사용합니다.",
                    "NSBluetoothPeripheralUsageDescription": "주변 명함을 교환하기 위해 블루투스를 사용합니다.",
                    "NFCReaderUsageDescription": "NFC로 명함 정보를 주고받습니다.",
                    "NSNearbyInteractionUsageDescription": "근거리에서 정확한 명함 교환을 위해 위치를 사용합니다.",
                    "NSLocationWhenInUseUsageDescription": "GPS 기반 스마트 출석 체크를 위해 위치 정보를 사용합니다.",
                    // Secrets/Shared.xcconfig(+ Secrets.xcconfig)에서 주입되는 값.
                    // UMCFoundation의 Config가 이 키들을 읽는다.
                    // (BASE_URL / KAKAO_KEY / TMAP_SECRET_KEY / GOOGLE_CLIENT_ID / GOOGLE_REVERSED_CLIENT_ID)
                    "BASE_URL": "$(BASE_URL)",
                    "KAKAO_KEY": "$(KAKAO_KEY)",
                    "TMAP_SECRET_KEY": "$(TMAP_SECRET_KEY)",
                    "GOOGLE_CLIENT_ID": "$(GOOGLE_CLIENT_ID)",
                    "GOOGLE_REVERSED_CLIENT_ID": "$(GOOGLE_REVERSED_CLIENT_ID)",
                    // GoogleSignIn SDK가 런타임에 직접 조회하는 키(GIDClientID)
                    "GIDClientID": "$(GOOGLE_CLIENT_ID)",
                    // Kakao/Google SDK 인증 리다이렉트용 URL Scheme
                    // (AuthConfig.kakaoURLScheme, googleReversedClientId와 동일 규칙)
                    "CFBundleURLTypes": [
                        [
                            "CFBundleURLSchemes": ["kakao$(KAKAO_KEY)"],
                        ],
                        [
                            "CFBundleURLSchemes": ["$(GOOGLE_REVERSED_CLIENT_ID)"],
                        ],
                        // 스레드 공유 딥링크 `umc://thread/{id}` (CommunityDomain.MessageLink)
                        [
                            "CFBundleURLName": "com.umc.product.deeplink",
                            "CFBundleURLSchemes": ["umc"],
                        ],
                    ],
                    "LSApplicationQueriesSchemes": [
                        "kakaokompassauth", "kakaolink", "kakaotalk", "kakaoplus",
                    ],
                    // 백그라운드에서 도착한 푸시를 AppDelegate가 받아 알림 보관함에 저장한다.
                    "UIBackgroundModes": ["remote-notification"],
                ]
            ),
            buildableFolders: [
                "UMCApp/Sources",
                "UMCApp/Resources",
            ],
            entitlements: .file(path: "UMCApp.entitlements"),
            scripts: [
                // 시크릿(Secrets.xcconfig / GoogleService-Info.plist) 누락 시 Release 빌드 중단.
                // Debug 는 경고만 — 신규 클론·CI 는 시크릿 없이도 빌드되어야 한다.
                // ENABLE_USER_SCRIPT_SANDBOXING=YES 이므로 스크립트 본체·읽는 파일을
                // inputPaths 로 선언해야 샌드박스가 접근을 허용한다(미선언 시 EPERM).
                .pre(
                    path: "Scripts/verify-secrets.sh",
                    name: "Verify Secrets",
                    inputPaths: [
                        "$(SRCROOT)/Scripts/verify-secrets.sh",
                        "$(SRCROOT)/UMCApp/Resources/GoogleService-Info.plist",
                    ],
                    basedOnDependencyAnalysis: false
                ),
            ],
            dependencies: [
                .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
                .project(target: "CoreRouting", path: .relativeToRoot("Core/Routing")),
                .project(target: "AuthPresentation", path: .relativeToRoot("Features/Auth")),
                .project(target: "AuthData", path: .relativeToRoot("Features/Auth")),
                .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
                .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
                .project(target: "NoticePresentation", path: .relativeToRoot("Features/Notice")),
                .project(target: "NoticeData", path: .relativeToRoot("Features/Notice")),
                .project(target: "ActivityDomain", path: .relativeToRoot("Features/Activity")),
                .project(target: "ActivityPresentation", path: .relativeToRoot("Features/Activity")),
                .project(target: "ActivityData", path: .relativeToRoot("Features/Activity")),
                .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
                .project(target: "HomePresentation", path: .relativeToRoot("Features/Home")),
                .project(target: "HomeData", path: .relativeToRoot("Features/Home")),
                .project(target: "CommunityDomain", path: .relativeToRoot("Features/Community")),
                .project(target: "CommunityPresentation", path: .relativeToRoot("Features/Community")),
                .project(target: "CommunityData", path: .relativeToRoot("Features/Community")),
                .project(target: "MyPagePresentation", path: .relativeToRoot("Features/MyPage")),
                .project(target: "MyPageData", path: .relativeToRoot("Features/MyPage")),
                .project(target: "BadgePresentation", path: .relativeToRoot("Features/Badge")),
                .project(
                    target: "MaintenancePresentation",
                    path: .relativeToRoot("Features/Maintenance")
                ),
                .project(target: "MaintenanceData", path: .relativeToRoot("Features/Maintenance")),
                .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
                .external(name: "FirebaseCore"),
                .external(name: "FirebaseMessaging"),
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
            bundleId: "com.umc.product.tests",
            deploymentTargets: .iOS("26.4"),
            infoPlist: .default,
            buildableFolders: [
                "UMCApp/Tests",
            ],
            dependencies: [.target(name: "UMCApp")]
        ),
    ]
)
