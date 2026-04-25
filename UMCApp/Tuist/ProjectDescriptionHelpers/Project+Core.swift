import ProjectDescription

private let bundleIdBase = "dev.umc.core"

/// Core 모듈용 Project 생성 헬퍼
///
/// Core 모듈은 단일 staticFramework 타겟으로 구성됩니다.
/// `includesTests: true`인 경우 `{name}Tests` unitTests 타겟이 함께 생성됩니다.
///
/// - Parameters:
///   - name: 타겟 이름 (예: "CoreNetwork", "UMCFoundation")
///   - bundleIdSuffix: bundleId 접미사 (예: "network", "foundation")
///   - destinations: 지원 플랫폼 (기본값: `.iOS`)
///   - deploymentTargets: 배포 대상 (기본값: iOS 26.3)
///   - dependencies: 메인 타겟 의존성 목록
///   - includesTests: `true`이면 `Tests/**` 소스를 사용하는 unitTests 타겟을 함께 생성
///   - testDependencies: 테스트 타겟에 추가로 주입할 의존성 (메인 타겟은 자동 포함)
///   - testEntitlements: 테스트 타겟용 entitlements 파일 (Keychain access 등)
public func coreProject(
    name: String,
    bundleIdSuffix: String,
    destinations: Destinations = .iOS,
    deploymentTargets: DeploymentTargets = .iOS("26.3"),
    dependencies: [TargetDependency] = [],
    includesTests: Bool = false,
    testDependencies: [TargetDependency] = [],
    testEntitlements: Path? = nil
) -> Project {
    var targets: [Target] = [
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

    if includesTests {
        targets.append(
            .target(
                name: "\(name)Tests",
                destinations: destinations,
                product: .unitTests,
                bundleId: "\(bundleIdBase).\(bundleIdSuffix).tests",
                deploymentTargets: deploymentTargets,
                sources: ["Tests/**"],
                entitlements: testEntitlements.map(Entitlements.file(path:)),
                dependencies: [.target(name: name)] + testDependencies
            )
        )
    }

    return Project(
        name: name,
        settings: recommendedProjectSettings,
        targets: targets
    )
}
