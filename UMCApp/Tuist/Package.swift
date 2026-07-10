// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        // Customize the product types for specific package product
        // Default is .staticFramework
        // productTypes: ["Alamofire": .framework,]
        productTypes: [:]
    )
#endif

let package = Package(
    name: "UMCApp",
    dependencies: [
        .package(url: "https://github.com/Moya/Moya.git", from: "15.0.3"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.6.1"),
        .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.27.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.1.0"),
        // 원격 킬스위치(점검)·강제 업데이트(#946)의 RemoteConfig 소스.
        // AppProduct(레거시)에서 검증된 버전(12.7.0)과 동일하게 고정한다.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.7.0"),
    ]
)
