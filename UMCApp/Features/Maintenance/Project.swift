import ProjectDescription
import ProjectDescriptionHelpers

let project = featureProject(
    name: "Maintenance",
    dataExtraDependencies: [
        // RemoteConfig 기반 킬스위치·강제 업데이트 판정(#946)이 Firebase SDK에 의존한다.
        .external(name: "FirebaseCore"),
        .external(name: "FirebaseRemoteConfig"),
    ],
    presentationExtraDependencies: [
        // `MaintenanceViewModel`이 다른 Presentation ViewModel과 동일하게
        // `container: DIContainer`를 주입받는다.
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
    ],
    includesDomainTests: true,
    includesDataTests: true,
    includesPresentationTests: true,
    presentationTestDependencies: [
        .project(target: "CoreDI", path: .relativeToRoot("Core/DI")),
    ]
)
