import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Home",
    // #1212: watch 출석 도메인이 ActivityDomain → HomeDomain 경로로 일정 모델
    // (ScheduleDetailData·ScheduleAttendancePolicy)을 그대로 재사용한다. 모델을 옮기지 않고
    // 지원 플랫폼만 넓혔다 — Domain 소스는 Foundation/UMCFoundation/NoticeDomain/SwiftData 만 쓴다.
    domainDestinations: [.iPhone, .appleWatch],
    domainDeploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    domainExtraDependencies: [
        // 최근 공지(#915)가 NoticeDomain의 조회 파이프라인(NoticeItemModel/NoticeListRequest 등)을 재사용한다.
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
    ],
    dataExtraDependencies: [
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    // staticFramework의 Compile Sources 산출물(.mlmodelc)은 소비 타겟까지 전파되지 않으므로,
    // 런타임 로드가 가능하도록 리소스 번들로도 명시한다 (ScheduleClassifierRepository 참고).
    dataResources: [
        "Data/Sources/MLModels/**",
    ],
    presentationExtraDependencies: [
        // 홈 진입 시 앱스토어 리뷰 요청(requestReview) 환경 값 사용.
        .sdk(name: "StoreKit", type: .framework),
        // 일정 상세의 "지도 보기"가 MKMapItem.openInMaps()로 Apple Maps를 연다.
        .sdk(name: "MapKit", type: .framework),
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        // 일정 상세의 출석 진입 분기가 전역 `UserSessionManager`의 활동 모드를 읽는다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        // 홈 루트가 공유 `PathStore` 의 홈 스택 깊이로 루트 복귀를 감지해 월별 일정을 재조회한다.
        .project(target: "CoreRouting", path: .relativeToRoot("Core/Routing")),
        // 일정 등록의 참여자 선택이 Activity 의 챌린저 검색 UI(SelectedChallengerView)를 그대로
        // 쓴다. ActivityDomain 은 그 이니셜라이저의 검색 UseCase 타입 해석에 필요하다.
        // Activity 쪽은 HomeDomain 만 참조하므로 타겟 그래프에 순환이 생기지 않는다.
        .project(target: "ActivityDomain", path: .relativeToRoot("Features/Activity")),
        .project(target: "ActivityPresentation", path: .relativeToRoot("Features/Activity")),
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .external(name: "Moya"),
        .target(name: "HomeDomain"),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        .project(target: "CoreNetwork", path: .relativeToRoot("Core/Network")),
        .project(target: "NoticeDomain", path: .relativeToRoot("Features/Notice")),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
