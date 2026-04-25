import ProjectDescription

private let companionBundleId = "dev.umc.appproduct"

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
                deploymentTargets: .watchOS("26.3"),
                infoPlist: .extendingDefault(
                    with: [
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
