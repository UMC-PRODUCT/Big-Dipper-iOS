import ProjectDescription

/// 호스트 iOS 앱의 번들 ID. Watch 앱 번들 ID는 반드시 `<이 값>.watchkitapp` 이어야 한다.
private let companionBundleId = "com.umc.product"

/// 호스트 iOS 앱이 쓰는 Icon Composer 아이콘을 Watch 앱도 그대로 쓴다.
/// `icon.json` 이 `supported-platforms.circles = ["watchOS"]` 로 원형 형상을 이미 선언하고 있어
/// watchOS 전용 에셋이 필요 없다. 사본을 두면 디자인 갱신 때 조용히 어긋나므로 원본을 직접 참조한다.
///
/// ⚠️ 이 경로가 어긋나도 Tuist 는 매칭 0건 glob 을 조용히 무시해 **아이콘 없이 빌드가 통과한다**.
/// 이슈 #1214(Watch 아이콘 0개)가 정확히 그 방식으로 발생했다. 호스트 아이콘을 옮기거나
/// 이름을 바꿀 때 이 상수도 반드시 같이 고치고, `Assets.car` 에 watch 렌디션이 남아있는지
/// 확인한다: `xcrun assetutil --info <앱>.app/Assets.car | grep -A6 '"Icon Image"'`
private let sharedAppIcon: ResourceFileElement = .glob(
    pattern: .relativeToRoot("UMCApp/Resources/AppIcon.icon")
)

/// Watch 앱 타겟용 Project 생성 헬퍼
///
/// watchOS App 타겟 1개를 구성합니다.
/// `includesTests: true`인 경우 `{name}Tests` unitTests 타겟이 함께 생성됩니다.
/// WKCompanionAppBundleIdentifier는 호스트 iOS 앱 번들 ID로 자동 설정됩니다.
/// 앱 아이콘은 호스트 iOS 앱의 `AppIcon.icon`(Icon Composer)을 원본 그대로 공유 참조합니다.
///
/// - Parameters:
///   - name: 타겟 이름 (예: "UMCWatchApp")
///   - bundleId: Watch 앱 번들 ID
///   - entitlements: entitlements 파일 경로 (기본값 nil)
///   - dependencies: 의존성 목록
///   - includesTests: `true`이면 `Tests/**` 소스를 사용하는 unitTests 타겟을 함께 생성
public func watchAppProject(
    name: String,
    bundleId: String,
    entitlements: Entitlements? = nil,
    dependencies: [TargetDependency] = [],
    includesTests: Bool = false
) -> Project {
    var targets: [Target] = [
        .target(
            name: name,
            destinations: [.appleWatch],
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .watchOS("26.4"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                    // watchOS 앱의 CFBundleVersion도 호스트 앱과 일치해야 업로드가 통과한다.
                    "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
                    "WKCompanionAppBundleIdentifier": .string(companionBundleId),
                    // 이 키가 없으면 빌드는 통과해도 시뮬레이터·기기 설치가 거부된다
                    // ("WatchKit app ... missing either the WKWatchKitApp or WKApplication").
                    "WKApplication": .boolean(true),
                    "UISupportedInterfaceOrientations": .array([
                        .string("UIInterfaceOrientationPortrait"),
                    ]),
                ]
            ),
            sources: ["Sources/**"],
            // `Resources/**` 는 현재 매칭 0건이다 — Watch 전용 에셋이 아직 없다.
            // 컴플리케이션 이미지 등이 생겼을 때 바로 잡히도록 선언만 남겨 둔다.
            resources: ["Resources/**", sharedAppIcon],
            entitlements: entitlements,
            dependencies: dependencies,
            // Tuist 기본값 `AccentColor` 는 Watch 쪽 카탈로그에 없어서
            // "Accent color 'AccentColor' is not present in any asset catalogs" 경고를 낸다.
            settings: .settings(base: ["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": ""])
        )
    ]

    if includesTests {
        targets.append(
            .target(
                name: "\(name)Tests",
                destinations: [.appleWatch],
                product: .unitTests,
                bundleId: "\(bundleId).tests",
                deploymentTargets: .watchOS("26.4"),
                sources: ["Tests/**"],
                dependencies: [.target(name: name)]
            )
        )
    }

    return Project(
        name: name,
        settings: recommendedProjectSettings,
        targets: targets
    )
}
