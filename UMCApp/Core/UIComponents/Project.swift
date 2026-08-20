import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreUIComponents",
    bundleIdSuffix: "uicomponents",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
        .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
        .external(name: "Kingfisher"),
        .sdk(name: "MapKit", type: .framework),
        .sdk(name: "TipKit", type: .framework),
    ],
    resources: [
        "Resources/Images.xcassets",
    ],
    additionalSettings: [
        // CoreDesignSystem과 동일한 규칙 — 자동 생성 심볼 대신 문자열 이름으로 접근한다.
        "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "NO",
    ],
    includesTests: true,
    testDependencies: [
        .project(target: "CoreDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
        // 시드 컬러 테스트가 UMCPartType 을 직접 나열한다. 전이 의존에 기대지 않고
        // import 하는 모듈을 명시 선언하는 게 이 레포 규약.
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ]
)
