import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "MyPage",
    domainExtraDependencies: [
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    dataExtraDependencies: [
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    presentationExtraDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CorePhoto", path: .relativeToRoot("Core/Photo")),
        // 소셜 연동 추가/해제(#1029)가 AuthDomain의 MemberOAuth UseCase와
        // CoreNetwork의 소셜 로그인 매니저를 사용한다.
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "AuthDomain", path: .relativeToRoot("Features/Auth")),
        .project(target: "BadgeDomain", path: .relativeToRoot("Features/Badge")),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .target(name: "MyPageDomain"),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation"))
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        // 소셜 연동(#1029) ViewModel 테스트가 AuthDomain UseCase 목을 직접 구성한다.
        .project(target: "AuthDomain", path: .relativeToRoot("Features/Auth")),
    ]
)
