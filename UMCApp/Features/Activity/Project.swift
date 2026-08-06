import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Activity",
    domainDestinations: [.iPhone, .appleWatch],
    domainDeploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    domainExtraDependencies: [
        // 출석 도메인이 일정 조회/생성을 HomeDomain 의 canonical 자산으로 수행한다.
        // (ScheduleDetailData·ScheduleLocation·ScheduleAttendancePolicy·ScheduleRepositoryProtocol)
        // Activity 안에 일정 모델을 다시 만들지 않는다 — #994 에서 세운 재사용 경계를
        // #981 에서 최종 확정했다: 전용 Schedule 모듈은 신설하지 않고 Home* 이 단일 소유자다.
        // (docs/claude/build-and-modules.md "경계 정책 — 일정(Schedule)")
        //
        // HomeDomain 은 iOS 전용이라 watchOS 까지 확장된 ActivityDomain 의 destination 을
        // 그대로 두려면 의존을 iOS 로 한정해야 한다. 현재 UMCWatchApp 은 CoreWatchConnectivity
        // 만 링크하므로 watch 빌드에 영향이 없다. watch 가 출석 도메인을 쓰게 되는 시점에
        // 일정 모델의 공용 위치(Core 승격 등)를 다시 판단한다.
        .project(
            target: "HomeDomain",
            path: .relativeToRoot("Features/Home"),
            condition: .when([.ios])
        ),
        // 챌린저 검색 결과(ChallengerSearchPage)가 Core canonical ChallengerInfo 를 담는다.
        // CoreDomain 은 iOS 전용이므로 HomeDomain 과 같은 이유로 조건부 의존이다.
        .project(
            target: "CoreDomain",
            path: .relativeToRoot("Core/Domain"),
            condition: .when([.ios])
        ),
    ],
    dataExtraDependencies: [
        // 출석 응답 DTO 가 HomeDomain 의 일정 장소/출석 정책 모델로 매핑한다.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
        // 챌린저 검색 DTO 가 ChallengerInfo 로 매핑한다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
    ],
    presentationExtraDependencies: [
        // 출석 ViewModel 이 ScheduleDetailData·ScheduleAttendancePolicy 를 직접 다룬다.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
        .project(target: "BusinessCardPresentation", path: .relativeToRoot("Features/BusinessCard")),
        // OperatorStudyManagementViewModel 이 멤버/멘토 선택 입력 타입(ChallengerInfo)을 사용.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        // ChallengerMemberListView 가 DIContainer 로 UseCase·세션을 resolve (Home/Notice 동일 패턴).
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
        // Activity 탭 루트가 공유 `PathStore` 로 자기 목적지를 push (Feature → App 의존 회피).
        .project(target: "CoreRouting", path: .relativeToRoot("Core/Routing")),
        // 출석 지도(BaseMapComponent/ActivityCompactMapView)가 Map·MapCircle·MKMapItem 사용.
        // CoreUIComponents·UMCFoundation 과 동일하게 SDK 프레임워크를 명시 링크한다.
        .sdk(name: "MapKit", type: .framework),
    ],
    includesDomainTests: true,
    domainTestDependencies: [
        // UseCase 테스트가 ScheduleDetailData 픽스처를 직접 만든다.
        // 테스트 타겟도 domainDestinations 를 물려받으므로 메인 타겟과 같은 iOS 한정 조건이 필요하다.
        .project(
            target: "HomeDomain",
            path: .relativeToRoot("Features/Home"),
            condition: .when([.ios])
        ),
        // UseCase 테스트가 ChallengerSearchPage 픽스처의 ChallengerInfo 를 직접 만든다.
        .project(
            target: "CoreDomain",
            path: .relativeToRoot("Core/Domain"),
            condition: .when([.ios])
        ),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesDataTests: true,
    dataTestDependencies: [
        .external(name: "Moya"),
        // Repository 테스트가 매핑 결과의 ScheduleLocation/ScheduleAttendancePolicy 를 검증.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
        // Repository 테스트가 챌린저 검색 매핑 결과(ChallengerInfo)를 검증.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        // Repository 테스트가 도메인 반환 타입(ScheduleAttendanceInfo 등)과
        // 에러 enum(DomainError/RepositoryError/NetworkError)을 직접 참조하므로 명시 주입.
        .target(name: "ActivityDomain"),
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    includesPresentationTests: true,
    presentationTestDependencies: [
        // VM 테스트가 ChallengerInfo 를 직접 생성하므로 명시 주입.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
        // VM 테스트가 ScheduleDetailData·ScheduleAttendancePolicy 픽스처를 직접 만든다.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
    ]
)
