import ProjectDescription

/// 빌드 번호 — TestFlight/App Store는 동일 `MARKETING_VERSION` 안에서 빌드 번호가 매번 달라야
/// 업로드를 받아준다. 아카이브 직전에 환경변수로 올린다:
///
/// ```bash
/// TUIST_BUILD_NUMBER=42 make generate
/// ```
///
/// 기본값 `1`은 로컬 개발용이다(업로드하지 않으므로 충돌하지 않는다).
private let buildNumber = Environment.buildNumber.getString(default: "1")

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
/// - `MARKETING_VERSION`: 앱 마케팅 버전(이슈 #948). 앱-노출 타겟의 CFBundleShortVersionString이 이 값을 참조한다.
/// - `CURRENT_PROJECT_VERSION`: 빌드 번호(이슈 #1128). 앱-노출 타겟의 CFBundleVersion이 이 값을 참조한다.
/// - `DEVELOPMENT_TEAM` / `CODE_SIGN_STYLE`: 서명 설정. Xcode UI에서 팀을 골라도 `tuist generate`
///   시 `.xcodeproj`이 재생성되며 날아가므로 매니페스트에 고정해야 아카이브가 반복 가능하다.
public let recommendedSettings: SettingsDictionary = [
    "ENABLE_MODULE_VERIFIER": "YES",
    "MODULE_VERIFIER_SUPPORTED_LANGUAGES": "objective-c objective-c++",
    "MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS": "gnu17 gnu++20",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
    "MARKETING_VERSION": "3.0.0",
    "CURRENT_PROJECT_VERSION": .string(buildNumber),
    "DEVELOPMENT_TEAM": "8B8B4462NV",
    "CODE_SIGN_STYLE": "Automatic",
]

/// 프로젝트 전역에 권장 빌드 설정을 적용한 Settings
public let recommendedProjectSettings: Settings = .settings(
    base: recommendedSettings
)
