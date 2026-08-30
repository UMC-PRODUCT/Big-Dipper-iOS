import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Notice",
    // #1212: HomeDomain 이 NoticeDomain 에 의존하므로, watch 가 쓰는 일정 모델 경로
    // (ActivityDomain → HomeDomain → NoticeDomain)를 잇기 위해 함께 연다.
    // 소스는 Foundation/UMCFoundation/SwiftData 만 쓰므로 watchOS 제약이 없다.
    domainDestinations: [.iPhone, .appleWatch],
    domainDeploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    presentationExtraDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        // `UserSessionManager`(#957 후속으로 CoreDomain에 승격)를 사용한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        // 투표자·작성자 프로필 조회에 MyPage 정본 Repository 프로토콜을 사용한다.
        .project(target: "MyPageDomain", path: .relativeToRoot("Features/MyPage")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .target(name: "NoticeDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ])
