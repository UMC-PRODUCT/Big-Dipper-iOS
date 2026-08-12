import ProjectDescription

/// 호스트 iOS 앱의 번들 ID. Watch 앱 번들 ID는 반드시 `<이 값>.watchkitapp` 이어야 한다.
private let companionBundleId = "com.umc.product"

/// Watch 앱 타겟용 Project 생성 헬퍼
///
/// watchOS App 타겟 1개를 구성합니다.
/// WKCompanionAppBundleIdentifier는 호스트 iOS 앱 번들 ID로 자동 설정됩니다.
///
/// - Parameters:
///   - name: 타겟 이름 (예: "UMCWatchApp")
///   - bundleId: Watch 앱 번들 ID
///   - entitlements: entitlements 파일 경로 (기본값 nil)
///   - dependencies: 의존성 목록
public func watchAppProject(
    name: String,
    bundleId: String,
    entitlements: Entitlements? = nil,
    dependencies: [TargetDependency] = []
) -> Project {
    Project(
        name: name,
        settings: recommendedProjectSettings,
        targets: [
            .target(
                name: name,
                destinations: [.appleWatch],
                product: .app,
                bundleId: bundleId,
                deploymentTargets: .watchOS("26.4"),
                infoPlist: .extendingDefault(
                    with: [
                        "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                        "WKCompanionAppBundleIdentifier": .string(companionBundleId),
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
    )
}
