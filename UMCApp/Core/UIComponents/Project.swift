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
    ]
)
