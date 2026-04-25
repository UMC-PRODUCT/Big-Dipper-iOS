import ProjectDescription

/// Xcode가 권장하는 최신 빌드 설정 모음
///
/// Xcode `Issue Navigator > Update to recommended settings` 다이얼로그에서 제안하는 항목 중
/// 프로젝트 전역으로 적용해도 안전한 설정을 모아둡니다.
///
/// Tuist는 매 generate 시 `.xcodeproj`을 재생성하므로, 이 설정은 반드시 매니페스트에서 관리해야
/// 다이얼로그가 다시 뜨지 않습니다.
///
/// 적용 항목:
/// - `ENABLE_MODULE_VERIFIER`: Clang 모듈 헤더 검증
/// - `ENABLE_USER_SCRIPT_SANDBOXING`: Run Script Phase 샌드박스
/// - `LOCALIZED_STRING_SWIFTUI_SUPPORT` / `STRING_CATALOG_GENERATE_SYMBOLS`: String Catalog 심볼 생성
public let recommendedSettings: SettingsDictionary = [
    "ENABLE_MODULE_VERIFIER": "YES",
    "MODULE_VERIFIER_SUPPORTED_LANGUAGES": "objective-c objective-c++",
    "MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS": "gnu17 gnu++20",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
]

/// 프로젝트 전역에 권장 빌드 설정을 적용한 Settings
public let recommendedProjectSettings: Settings = .settings(
    base: recommendedSettings
)
