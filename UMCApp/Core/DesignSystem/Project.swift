import ProjectDescription
import ProjectDescriptionHelpers

let project = coreProject(
    name: "CoreDesignSystem",
    bundleIdSuffix: "designsystem",
    dependencies: [
        .project(target: "UMCFoundation", path: .relativeToRoot("Core/Foundation")),
    ],
    resources: [
        "Resources/Fonts/**",
        "Resources/Colors.xcassets",
    ],
    additionalSettings: [
        // Asset Catalog 자동 생성 Color/Image 심볼 비활성화.
        // 자동 생성된 extension 은 internal 접근이라 외부 모듈에서 못 쓰므로,
        // `Color+Tokens.swift` 에서 public 으로 직접 노출합니다.
        "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "NO",
    ]
)
