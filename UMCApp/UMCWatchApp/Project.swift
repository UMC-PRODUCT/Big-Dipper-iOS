import ProjectDescription
import ProjectDescriptionHelpers

let project = watchAppProject(
    name: "UMCWatchApp",
    bundleId: "com.umc.product.watchkitapp",
    entitlements: .file(path: "UMCWatchApp.entitlements"),
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
        .project(target: "CoreWatchDesignSystem", path: .relativeToRoot("Core/WatchDesignSystem")),
        // 워치 출석 화면이 시간대 판정(AttendanceTimeWindow)을 ActivityDomain 에서 가져온다.
        .project(target: "ActivityDomain", path: .relativeToRoot("Features/Activity")),
        // 같은 화면이 일정 모델(ScheduleDetailData)을 직접 다루므로 HomeDomain 도 명시 링크한다.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
        // 출석 화면 상태를 Loadable/AppError 로 표현한다. HomeDomain 경유 전파에 기대지 않고
        // 직접 쓰는 모듈이므로 명시 링크한다.
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        // `.project(target:)` 로 appExtension 을 걸면 Tuist 가 워치 앱 PlugIns 에 자동 임베드한다.
        .project(target: "UMCWatchComplication", path: .relativeToRoot("UMCWatchComplication")),
    ],
    includesTests: true
)
