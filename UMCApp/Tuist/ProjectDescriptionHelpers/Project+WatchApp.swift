import ProjectDescription

/// 호스트 iOS 앱의 번들 ID. Watch 앱 번들 ID는 반드시 `<이 값>.watchkitapp` 이어야 한다.
private let companionBundleId = "com.umc.product"

/// Watch 앱 타겟용 Project 생성 헬퍼
///
/// watchOS App 타겟 1개를 구성합니다.
/// `includesTests: true`인 경우 `{name}Tests` unitTests 타겟이 함께 생성됩니다.
/// WKCompanionAppBundleIdentifier는 호스트 iOS 앱 번들 ID로 자동 설정됩니다.
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
            resources: ["Resources/**"],
            entitlements: entitlements,
            dependencies: dependencies
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
