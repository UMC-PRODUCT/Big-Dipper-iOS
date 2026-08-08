import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Notice",
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
