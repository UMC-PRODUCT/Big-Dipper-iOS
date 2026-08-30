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
        // #1212 에서 확정: 일정 모델은 옮기지 않는다. HomeDomain(+NoticeDomain)·CoreDomain 의
        // Domain 타겟을 [.iPhone, .appleWatch] 로 열어 watch 가 canonical 자산을 그대로 재사용한다.
        // #981 의 "Home* 단일 소유자" 경계는 그대로 유지되며 지원 플랫폼만 넓어졌다.
        // 세 Domain 타겟 모두 Foundation/UMCFoundation/SwiftData 만 사용해 watchOS 제약이 없다.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
        // 챌린저 검색 결과(ChallengerSearchPage)가 Core canonical ChallengerInfo 를 담는다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
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
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
        // UseCase 테스트가 ChallengerSearchPage 픽스처의 ChallengerInfo 를 직접 만든다.
        .project(target: "CoreDomain", path: .relativeToRoot("Core/Domain")),
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
