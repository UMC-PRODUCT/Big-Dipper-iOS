// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stella",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "StellaCore", targets: ["StellaCore"]),
        .library(name: "StellaTestSupport", targets: ["StellaTestSupport"]),
        .executable(name: "apicov", targets: ["apicov"]),
        .executable(name: "stella", targets: ["StellaApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "StellaCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/StellaCore"
        ),
        .target(
            name: "StellaTestSupport",
            dependencies: ["StellaCore"],
            path: "Sources/StellaTestSupport"
        ),
        .executableTarget(
            name: "apicov",
            dependencies: [
                "StellaCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/apicov"
        ),
        .executableTarget(
            name: "StellaApp",
            dependencies: ["StellaCore"],
            path: "Sources/StellaApp",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "StellaCoreTests",
            dependencies: ["StellaCore", "StellaTestSupport"],
            path: "Tests/StellaCoreTests",
            resources: [.copy("../../Fixtures")]
        ),
        .testTarget(
            name: "apicovTests",
            dependencies: ["apicov", "StellaCore", "StellaTestSupport"],
            path: "Tests/apicovTests",
            resources: [.copy("../../Fixtures")]
        ),
    ]
)
