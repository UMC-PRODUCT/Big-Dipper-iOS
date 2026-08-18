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
        // 탭 루트가 자기 목적지(MyPageDestination)를 탭 스택에 push 한다.
        .project(target: "CoreRouting", path: .relativeToRoot("Core/Routing")),
        // 로그아웃/탈퇴가 UserSessionManager·MemberProfileRepository 캐시를 직접 정리한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        // 소셜 연동 추가/해제(#1029)가 AuthDomain의 MemberOAuth UseCase와
        // CoreNetwork의 소셜 로그인 매니저를 사용한다.
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "AuthDomain", path: .relativeToRoot("Features/Auth")),
        .project(target: "BadgeDomain", path: .relativeToRoot("Features/Badge")),
        // 로그아웃/탈퇴가 DI 캐시를 비우기 전에 STOMP 연결을 stop() 해야 한다.
        .project(target: "CommunityDomain", path: .relativeToRoot("Features/Community")),
        // v3 루트가 명함 카드를 직접 그린다. 카드 UI(BusinessCardFaceView)를 MyPage가
        // 재구현하면 중복이라 BusinessCardPresentation을 재사용하고, MyCard·ActivityStat
        // 모델은 BusinessCardDomain 소유다.
        .project(target: "BusinessCardDomain", path: .relativeToRoot("Features/BusinessCard")),
        .project(
            target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")
        ),
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
        // loadBusinessCard ViewModel 테스트가 MyCard·ActivityStat·BusinessCardUseCaseProviding을
        // 직접 구성한다. BusinessCardUseCaseProviding의 미사용 멤버(교환·QR 등)까지 전부
        // 구현해야 컴파일되므로 그 시그니처가 쓰는 CoreNearbyExchange 타입도 함께 필요하다.
        .project(target: "BusinessCardDomain", path: .relativeToRoot("Features/BusinessCard")),
        .project(
            target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")
        ),
        .project(target: "CoreNearbyExchange", path: .relativeToRoot("Core/NearbyExchange")),
    ]
)
