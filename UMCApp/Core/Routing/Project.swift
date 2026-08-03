import ProjectDescription
import ProjectDescriptionHelpers

// 라우팅 기반 모듈은 어떤 Feature 에도 의존하지 않는다.
// 각 Feature 가 자기 목적지 타입을 소유하고, App 이 탭 스택에 타입별로 등록한다.
// (Core → Feature 의존이 생기면 탭이 늘어날 때마다 Core 가 Feature 도메인에 결합된다.)
let project = coreProject(
    name: "CoreRouting",
    bundleIdSuffix: "routing",
    includesTests: true
)
