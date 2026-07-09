import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Auth",
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        // 승인 대기(#945) 화면의 회원 탈퇴 액션이 MyPageDomain의 UseCase를 직접 사용한다.
        .project(target: "MyPageDomain", path: .relativeToRoot("Features/MyPage")),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .external(name: "Moya"),
        .target(name: "AuthDomain"),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        // 승인 대기(#945) ViewModel 테스트에서 DeleteMemberUseCaseProtocol 목을 직접 구성한다.
        .project(target: "MyPageDomain", path: .relativeToRoot("Features/MyPage")),
    ]
)
