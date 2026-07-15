import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Activity",
    domainDestinations: [.iPhone, .appleWatch],
    domainDeploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        // OperatorStudyManagementViewModel 이 멤버/멘토 선택 입력 타입(ChallengerInfo)을 사용.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    includesDomainTests: true,
    includesDataTests: true,
    dataTestDependencies: [
        .external(name: "Moya"),
        // Repository 테스트가 도메인 반환 타입(ScheduleAttendanceInfo 등)과
        // 에러 enum(DomainError/RepositoryError/NetworkError)을 직접 참조하므로 명시 주입.
        .target(name: "ActivityDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        // VM 테스트가 ChallengerInfo 를 직접 생성하므로 명시 주입.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ]
)
