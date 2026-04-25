import ProjectDescription

private let bundleIdBase = "dev.umc.feature"

/// Feature 모듈용 Project 생성 헬퍼
///
/// 각 Feature는 Domain / Data / Presentation 세 개의 staticFramework 타겟으로 구성됩니다.
/// - Domain: UMCFoundation 의존
/// - Data: {Name}Domain + CoreNetwork + UMCFoundation 의존
/// - Presentation: {Name}Domain + CoreDesignSystem + CoreUIComponents + UMCFoundation 의존
///
/// - Parameters:
///   - name: Feature 이름 (예: "Auth", "Home"). 타겟명 및 bundleId 생성에 사용됩니다.
///   - domainDestinations: Domain 타겟의 지원 플랫폼 (기본값: `.iOS`). watchOS 공유가 필요한 경우 `[.iPhone, .appleWatch]`로 지정.
///   - domainDeploymentTargets: Domain 타겟의 배포 대상 (기본값: iOS 26.3). watchOS 공유 시 `.multiplatform(iOS:watchOS:)` 로 지정.
///   - domainExtraDependencies: Domain 타겟에 추가할 의존성
///   - dataExtraDependencies: Data 타겟에 추가할 의존성
///   - presentationExtraDependencies: Presentation 타겟에 추가할 의존성
public func featureProject(
    name: String,
    domainDestinations: Destinations = .iOS,
    domainDeploymentTargets: DeploymentTargets = .iOS("26.3"),
    domainExtraDependencies: [TargetDependency] = [],
    dataExtraDependencies: [TargetDependency] = [],
    presentationExtraDependencies: [TargetDependency] = []
) -> Project {
    let nameLowered = name.lowercased()

    return Project(
        name: name,
        settings: recommendedProjectSettings,
        targets: [
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
                deploymentTargets: .iOS("26.3"),
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
                deploymentTargets: .iOS("26.3"),
                sources: ["Presentation/Sources/**"],
                dependencies: [
                    .target(name: "\(name)Domain"),
                    .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
                    .project(target: "CoreUIComponents", path: .relativeToRoot("Core/UIComponents")),
                    .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
                ] + presentationExtraDependencies
            ),
        ]
    )
}
