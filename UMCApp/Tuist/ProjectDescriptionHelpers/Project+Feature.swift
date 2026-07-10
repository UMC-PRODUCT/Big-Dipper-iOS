import ProjectDescription

private let bundleIdBase = "dev.umc.feature"

/// Feature 모듈용 Project 생성 헬퍼
///
/// 각 Feature는 Domain / Data / Presentation 세 개의 staticFramework 타겟으로 구성됩니다.
/// - Domain: UMCFoundation 의존
/// - Data: {Name}Domain + CoreNetwork + UMCFoundation 의존
/// - Presentation: {Name}Domain + CoreDesignSystem + CoreUIComponents + UMCFoundation 의존
///
/// 테스트 타겟은 레이어별로 옵션 활성화 시 생성됩니다 (`{Name}DomainTests`, `{Name}DataTests`, `{Name}PresentationTests`).
/// 메인 타겟은 자동으로 의존성에 포함됩니다.
///
/// - Parameters:
///   - name: Feature 이름 (예: "Auth", "Home"). 타겟명 및 bundleId 생성에 사용됩니다.
///   - domainDestinations: Domain 타겟의 지원 플랫폼 (기본값: `.iOS`). watchOS 공유가 필요한 경우 `[.iPhone, .appleWatch]`로 지정.
///   - domainDeploymentTargets: Domain 타겟의 배포 대상 (기본값: iOS 26.4). watchOS 공유 시 `.multiplatform(iOS:watchOS:)` 로 지정.
///   - domainExtraDependencies: Domain 타겟에 추가할 의존성
///   - dataExtraDependencies: Data 타겟에 추가할 의존성
///   - presentationExtraDependencies: Presentation 타겟에 추가할 의존성
///   - includesDomainTests: `true`이면 `Domain/Tests/**` 소스를 사용하는 unitTests 타겟 생성
///   - domainTestDependencies: Domain 테스트 타겟에 추가로 주입할 의존성 (메인 Domain은 자동 포함)
///   - includesDataTests: `true`이면 `Data/Tests/**` 소스를 사용하는 unitTests 타겟 생성
///   - dataTestDependencies: Data 테스트 타겟에 추가로 주입할 의존성 (메인 Data는 자동 포함)
///   - includesPresentationTests: `true`이면 `Presentation/Tests/**` 소스를 사용하는 unitTests 타겟 생성
///   - presentationTestDependencies: Presentation 테스트 타겟에 추가로 주입할 의존성 (메인 Presentation은 자동 포함)
public func featureProject(
    name: String,
    domainDestinations: Destinations = .iOS,
    domainDeploymentTargets: DeploymentTargets = .iOS("26.4"),
    domainExtraDependencies: [TargetDependency] = [],
    dataExtraDependencies: [TargetDependency] = [],
    presentationExtraDependencies: [TargetDependency] = [],
    includesDomainTests: Bool = false,
    domainTestDependencies: [TargetDependency] = [],
    includesDataTests: Bool = false,
    dataTestDependencies: [TargetDependency] = [],
    includesPresentationTests: Bool = false,
    presentationTestDependencies: [TargetDependency] = []
) -> Project {
    let nameLowered = name.lowercased()

    var targets: [Target] = [
        .target(
            name: "\(name)Domain",
            destinations: domainDestinations,
            product: .staticFramework,
            bundleId: "\(bundleIdBase).\(nameLowered).domain",
            deploymentTargets: domainDeploymentTargets,
            sources: ["Domain/Sources/**"],
            dependencies: [
                .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
            ] + domainExtraDependencies
        ),
        .target(
            name: "\(name)Data",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "\(bundleIdBase).\(nameLowered).data",
            deploymentTargets: .iOS("26.4"),
            sources: ["Data/Sources/**"],
            dependencies: [
                .target(name: "\(name)Domain"),
                .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
                .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
            ] + dataExtraDependencies
        ),
        .target(
            name: "\(name)Presentation",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "\(bundleIdBase).\(nameLowered).presentation",
            deploymentTargets: .iOS("26.4"),
            sources: ["Presentation/Sources/**"],
            dependencies: [
                .target(name: "\(name)Domain"),
                .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
                .project(target: "CoreUIComponents", path: .relativeToRoot("Core/UIComponents")),
                .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
            ] + presentationExtraDependencies
        ),
    ]

    if includesDomainTests {
        targets.append(
            .target(
                name: "\(name)DomainTests",
                destinations: domainDestinations,
                product: .unitTests,
                bundleId: "\(bundleIdBase).\(nameLowered).domain.tests",
                deploymentTargets: domainDeploymentTargets,
                sources: ["Domain/Tests/**"],
                dependencies: [.target(name: "\(name)Domain")] + domainTestDependencies
            )
        )
    }

    if includesDataTests {
        targets.append(
            .target(
                name: "\(name)DataTests",
                destinations: .iOS,
                product: .unitTests,
                bundleId: "\(bundleIdBase).\(nameLowered).data.tests",
                deploymentTargets: .iOS("26.4"),
                sources: ["Data/Tests/**"],
                dependencies: [.target(name: "\(name)Data")] + dataTestDependencies
            )
        )
    }

    if includesPresentationTests {
        targets.append(
            .target(
                name: "\(name)PresentationTests",
                destinations: .iOS,
                product: .unitTests,
                bundleId: "\(bundleIdBase).\(nameLowered).presentation.tests",
                deploymentTargets: .iOS("26.4"),
                sources: ["Presentation/Tests/**"],
                dependencies: [.target(name: "\(name)Presentation")] + presentationTestDependencies
            )
        )
    }

    return Project(
        name: name,
        settings: recommendedProjectSettings,
        targets: targets
    )
}
