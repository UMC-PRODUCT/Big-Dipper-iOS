import ProjectDescription
import ProjectDescriptionHelpers

// WidgetKit 을 무는 이유는 하나다 — `ComplicationStore.save` 가 저장 직후 워치페이스 타임라인을
// 리로드한다. 저장과 리로드를 갈라 두면 호출자가 리로드를 빠뜨려 값이 조용히 낡는다.
let project = coreProject(
    name: "CoreWatchConnectivity",
    bundleIdSuffix: "watchconnectivity",
    destinations: [.iPhone, .appleWatch],
    deploymentTargets: .multiplatform(iOS: "26.4", watchOS: "26.4"),
    dependencies: [
        .sdk(name: "WatchConnectivity", type: .framework, status: .required),
        .sdk(name: "WidgetKit", type: .framework, status: .required),
    ],
    includesTests: true
)
