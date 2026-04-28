// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "APICoverage",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "APICoverageCore", targets: ["APICoverageCore"]),
        .library(name: "APICoverageTestSupport", targets: ["APICoverageTestSupport"]),
        .executable(name: "apicov", targets: ["apicov"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "APICoverageCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/APICoverageCore"
        ),
        .target(
            name: "APICoverageTestSupport",
            dependencies: ["APICoverageCore"],
            path: "Sources/APICoverageTestSupport"
        ),
        .executableTarget(
            name: "apicov",
            dependencies: [
                "APICoverageCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/apicov"
        ),
        .testTarget(
            name: "APICoverageCoreTests",
            dependencies: ["APICoverageCore", "APICoverageTestSupport"],
            path: "Tests/APICoverageCoreTests",
            resources: [.copy("../../Fixtures")]
        ),
        .testTarget(
            name: "apicovTests",
            dependencies: ["apicov", "APICoverageCore", "APICoverageTestSupport"],
            path: "Tests/apicovTests",
            resources: [.copy("../../Fixtures")]
        ),
    ]
)
