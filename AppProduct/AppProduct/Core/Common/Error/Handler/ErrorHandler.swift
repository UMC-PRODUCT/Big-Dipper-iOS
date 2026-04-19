//
//  ErrorHandler.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation
import FoundationModels
import os.log

/// 앱 전역에서 발생하는 에러를 중앙 집중식으로 처리하는 핸들러.
///
/// Mediator 패턴을 적용하여 여러 ViewModel에서 발생하는 에러를 한 곳에서 수집하고 처리합니다.
///
/// ErrorHandler의 역할:
/// 1. 에러 변환: `MoyaError`, `URLError` 등을 ``AppError``로 통합
/// 2. 로깅: `os.log`를 사용하여 에러 정보 기록
/// 3. 분석: Firebase, Sentry 등 외부 서비스로 에러 데이터 전송
/// 4. 특수 처리: 401 Unauthorized → 자동 로그아웃
/// 5. UI 바인딩: ``currentError``를 통해 View에서 Alert 표시
///
/// ## Usage
///
/// **App에서 Environment로 주입:**
///
/// ```swift
/// @main
/// struct AppProductApp: App {
///     @State private var errorHandler = ErrorHandler()
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(errorHandler)
///                 .globalErrorAlert(errorHandler: errorHandler)
///         }
///     }
/// }
/// ```
///
/// **ViewModel에서 에러 처리:**
///
/// ```swift
/// func fetchNotices() async {
///     do {
///         notices = try await useCase.execute()
///     } catch {
///         errorHandler.handle(error, context: ErrorContext(
///             feature: "Notice",
///             action: "fetchList",
///             retryAction: { [weak self] in await self?.fetchNotices() }
///         ))
///     }
/// }
/// ```
///
/// - Important: 에러 처리 방식은 UX 관점에서 결정하세요.
///   - **ErrorHandler**: 작업 흐름 중단, 즉각적인 사용자 액션이 필요한 경우 (Alert)
///   - **Loadable**: 데이터 상태와 함께 관리, 화면 내 상태 변화 표시 (인라인)
///
///   예시:
///   - 세션 만료, 권한 필요, 네트워크 오류 → ErrorHandler
///   - 리스트 로딩 실패, 폼 검증 실패, 범위 벗어남 → Loadable
///
/// - Warning: 현재 특수 에러 처리는 `NotificationCenter`를 사용합니다.
///   추후 `AppState + Environment` 패턴으로 리팩터링 예정입니다.
///
/// - SeeAlso: ``ErrorContext``, ``AppError``, ``PresentableError``, ``Loadable``
@Observable
final class ErrorHandler {

    // MARK: - Property

    /// 현재 표시해야 할 에러.
    ///
    /// View에서 이 값을 관찰하여 에러 Alert을 표시합니다.
    /// `nil`이면 에러가 없는 상태입니다.
    ///
    /// - Note: 외부에서 직접 수정할 수 없습니다. ``handle(_:context:)``를 사용하세요.
    private(set) var currentError: PresentableError?

    /// 에러 로깅에 사용되는 Logger.
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AppProduct",
        category: "ErrorHandler"
    )

    // MARK: - Init

    /// ErrorHandler를 초기화합니다.
    ///
    /// App 레벨에서 한 번만 생성하고 Environment로 주입합니다.
    init() {}

    // MARK: - Public Methods

    /// 에러를 처리합니다.
    ///
    /// 에러 처리의 단일 진입점입니다. 다음 순서로 처리합니다:
    /// 1. `Error` → ``AppError`` 변환
    /// 2. os.log로 로깅
    /// 3. Analytics 전송
    /// 4. 특수 케이스 처리 (401 → 로그아웃)
    /// 5. ``currentError`` 설정 → View에서 Alert 표시
    ///
    /// - Parameters:
    ///   - error: 발생한 에러. ``AppError``, `MoyaError`, `URLError` 등 모든 `Error` 타입 가능.
    ///   - context: 에러 발생 위치와 재시도 정보를 담은 컨텍스트.
    ///
    /// - Precondition: Main Thread에서 호출해야 합니다.
    func handle(_ error: Error, context: ErrorContext) {
        // 사용자가 의도적으로 취소한 경우 — Alert 없이 종료
        if error is CancellationError {
            logger.info("[\(context.feature)/\(context.action)] Task cancelled")
            return
        }

        let appError = convert(error)

        log(appError, context: context)
        trackError(appError, context: context)

        if handleSpecialCases(appError, context: context) {
            return
        }

        currentError = PresentableError(
            error: appError,
            context: context,
            dismissAction: { [weak self] in
                self?.clearError()
            },
            retryAction: context.retryAction
        )
    }

    /// 현재 표시 중인 에러를 초기화합니다.
    ///
    /// 에러 Alert이 닫힐 때 자동으로 호출됩니다.
    func clearError() {
        currentError = nil
    }

    // MARK: - Private Methods

    /// 임의의 Error를 AppError로 변환합니다.
    ///
    /// - Parameter error: 변환할 에러.
    /// - Returns: 통합된 ``AppError``.
    ///
    /// - Note: 지원 타입: `AppError`, `NetworkError`, `RepositoryError`, `AuthError`,
    ///   `ValidationError`, `DomainError`, `MoyaError`, `URLError`, `DecodingError`
    private func convert(_ error: Error) -> AppError {
        // 1. AppError는 그대로 반환
        if let appError = error as? AppError {
            return appError
        }

        // 2. NetworkError → AppError.network (Actor 기반 네트워크 클라이언트)
        if let networkError = error as? NetworkError {
            return .network(networkError)
        }

        // 3. RepositoryError
        if let repositoryError = error as? RepositoryError {
            return .repository(repositoryError)
        }

        // 4. ValidationError
        if let validationError = error as? ValidationError {
            return .validation(validationError)
        }

        // 5. AuthError
        if let authError = error as? AuthError {
            return .auth(authError)
        }

        // 6. DomainError
        if let domainError = error as? DomainError {
            return .domain(domainError)
        }

        // 7. URLError → NetworkError 변환
        if let urlError = error as? URLError {
            return .network(convertURLError(urlError))
        }

        // 8. DecodingError → RepositoryError 변환
        if let decodingError = error as? DecodingError {
            return .repository(.decodingError(detail: describeDecodingError(decodingError)))
        }

        // 9. LanguageModelSession.GenerationError → DomainError 변환
        if let generationError = error as? LanguageModelSession.GenerationError {
            return .domain(.custom(message: describeGenerationError(generationError)))
        }

        // 10. 알 수 없는 에러
        return .unknown(message: error.localizedDescription)
    }

    private func convertURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noNetwork
        case .timedOut:
            return .timeout
        default:
            return .requestFailed(statusCode: error.errorCode, data: nil)
        }
    }

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let location = path.isEmpty ? key.stringValue : "\(path).\(key.stringValue)"
            return "Missing key: \(location)"
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch: expected \(type) at \(path)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Value not found: \(type) at \(path)"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }

    private func describeGenerationError(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "입력이 너무 깁니다. 내용을 줄여서 다시 시도해주세요."
        case .assetsUnavailable:
            return "AI 모델이 아직 준비되지 않았습니다. 잠시 후 다시 시도해주세요."
        case .guardrailViolation:
            return "안전 정책에 의해 처리할 수 없는 내용입니다."
        case .unsupportedGuide:
            return "지원하지 않는 형식입니다."
        case .unsupportedLanguageOrLocale:
            return "지원하지 않는 언어입니다."
        case .decodingFailure:
            return "AI 응답을 처리하는 중 문제가 발생했습니다."
        case .rateLimited:
            return "AI 요청이 너무 빠릅니다. 잠시 후 다시 시도해주세요."
        case .concurrentRequests:
            return "이미 AI 요청이 진행 중입니다."
        case .refusal(_, _):
            return "AI가 요청을 거부했습니다. 다른 표현으로 다시 시도해주세요."
        @unknown default:
            return "AI 처리 중 문제가 발생했습니다."
        }
    }

    // MARK: - Logging

    /// 에러를 os.log로 기록합니다.
    ///
    /// 로그 레벨은 에러의 ``AppError/severity``에 따라 결정됩니다.
    private func log(_ error: AppError, context: ErrorContext) {
        let message = """
        [Error] \(context.feature)/\(context.action)
        - Error: \(error.errorDescription ?? "Unknown")
        - Severity: \(error.severity)
        - Retryable: \(error.isRetryable)
        """

        switch error.severity {
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .critical:
            logger.error("\(message)")
        }
    }

    // MARK: - Analytics

    /// 에러를 외부 분석 서비스로 전송합니다.
    ///
    /// - Todo: Firebase Analytics, Sentry 등 연동
    private func trackError(_ error: AppError, context: ErrorContext) {
        // TODO: Firebase Analytics, Sentry 등 연동 - [25.01.07] 이재원
    }

    // MARK: - Special Cases

    // TODO: [Refactor] NotificationCenter → AppState + Environment 패턴으로 리팩터링 예정 - [25.01.07] 이재원
    // 현재: NotificationCenter 사용 (타입 안전하지 않음)
    // 개선: AppState를 주입받아 직접 상태 변경 (DIContainer 구현 후)

    /// 특수 에러를 처리합니다.
    ///
    /// Alert 표시 대신 앱 전체 상태 변경이 필요한 에러를 처리합니다.
    ///
    /// - Parameters:
    ///   - error: 처리할 에러.
    ///   - context: 에러 컨텍스트.
    /// - Returns: 특수 처리가 수행되었으면 `true`.
    ///
    /// - Warning: 현재 `NotificationCenter`를 사용합니다. 추후 리팩터링 필요.
    private func handleSpecialCases(_ error: AppError, context: ErrorContext) -> Bool {
        switch error {
        // 인증 만료 → 자동 로그아웃
        case .auth(.sessionExpired):
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            return true

        // NetworkError 인증 관련 에러 → 자동 로그아웃
        case .network(.unauthorized),
             .network(.tokenRefreshFailed),
             .network(.noRefreshToken),
             .network(.maxRetryExceeded):
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            return true

        // 승인 대기 상태 → 대기 화면으로 이동
        case .auth(.pendingApproval):
            NotificationCenter.default.post(name: .navigateToPendingApproval, object: nil)
            return true

        default:
            return false
        }
    }
}
