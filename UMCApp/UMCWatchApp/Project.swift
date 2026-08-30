import ProjectDescription
import ProjectDescriptionHelpers

let project = watchAppProject(
    name: "UMCWatchApp",
    bundleId: "com.umc.product.watchkitapp",
    dependencies: [
        .project(target: "CoreWatchConnectivity", path: .relativeToRoot("Core/WatchConnectivity")),
        .project(target: "CoreWatchDesignSystem", path: .relativeToRoot("Core/WatchDesignSystem")),
        // 워치 출석 화면이 시간대 판정(AttendanceTimeWindow)을 ActivityDomain 에서 가져온다.
        .project(target: "ActivityDomain", path: .relativeToRoot("Features/Activity")),
        // 같은 화면이 일정 모델(ScheduleDetailData)을 직접 다루므로 HomeDomain 도 명시 링크한다.
        .project(target: "HomeDomain", path: .relativeToRoot("Features/Home")),
    ],
    includesTests: true
)
