import ProjectDescription

private let deploymentTargets: DeploymentTargets = .iOS("26.3")
private let destinations: Destinations = .iOS

/// Widget Extension 타겟용 Project 생성 헬퍼
///
/// Widget Extension은 단일 appExtension 타겟으로 구성됩니다.
/// WidgetKit extension에 필요한 Info.plist 항목을 자동으로 포함합니다.
///
/// - Parameters:
///   - name: 타겟 이름 (예: "UMCAppWidget")
///   - bundleId: 완전한 번들 ID — 반드시 호스트 앱 번들 ID를 prefix로 포함해야 합니다
///   - entitlements: entitlements 파일 경로 (기본값 nil)
///   - dependencies: 의존성 목록
public func widgetExtensionProject(
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
                destinations: destinations,
                product: .appExtension,
                bundleId: bundleId,
                deploymentTargets: deploymentTargets,
                infoPlist: .extendingDefault(
                    with: [
                        "NSExtension": [
                            "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                        ],
                    ]
                ),
                sources: ["Sources/**"],
                entitlements: entitlements,
                dependencies: dependencies
            )
        ]
    )
}
