import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Auth",
    domainExtraDependencies: [
        // `SyncProfileStorageUseCase`가 전역 `UserSessionManager`(#957 후속)를 주입받는다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    dataExtraDependencies: [
        // `MemberMeResponseDTO`가 정본 `ProfileGenerationOrganization`(#961)을 참조한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    presentationExtraDependencies: [
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        // 승인 대기 화면의 로그아웃/탈퇴가 전역 `UserSessionManager.reset()`(#959)을 호출한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        // 승인 대기(#945) 화면의 회원 탈퇴 액션이 MyPageDomain의 UseCase를 직접 사용한다.
        .project(target: "MyPageDomain", path: .relativeToRoot("Features/MyPage")),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
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
        // 로그아웃/탈퇴 시 `UserSessionManager.reset()` 배선(#959)을 실제 인스턴스로 검증한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        // 승인 대기(#945) ViewModel 테스트에서 DeleteMemberUseCaseProtocol 목을 직접 구성한다.
        .project(target: "MyPageDomain", path: .relativeToRoot("Features/MyPage")),
    ]
)
