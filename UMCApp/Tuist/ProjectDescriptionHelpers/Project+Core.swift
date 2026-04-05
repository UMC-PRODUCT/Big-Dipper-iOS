import ProjectDescription

private let deploymentTargets: DeploymentTargets = .iOS("26.0")
private let destinations: Destinations = .iOS
private let bundleIdBase = "dev.umc.core"

/// Core 모듈용 Project 생성 헬퍼
///
/// Core 모듈은 단일 staticFramework 타겟으로 구성됩니다.
///
/// - Parameters:
///   - name: 타겟 이름 (예: "CoreNetwork", "UMCFoundation")
///   - bundleIdSuffix: bundleId 접미사 (예: "network", "foundation")
///   - dependencies: 의존성 목록
public func coreProject(
    name: String,
    bundleIdSuffix: String,
    dependencies: [TargetDependency] = []
) -> Project {
    Project(
        name: name,
        targets: [
            .target(
                name: name,
                destinations: destinations,
                product: .staticFramework,
                bundleId: "\(bundleIdBase).\(bundleIdSuffix)",
                deploymentTargets: deploymentTargets,
                sources: ["Sources/**"],
                dependencies: dependencies
            )
        ]
    )
}
