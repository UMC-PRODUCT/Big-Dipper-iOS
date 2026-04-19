//
//  ErrorHandler.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation
import FoundationModels
import os.log

@Observable
final class ErrorHandler {

    // MARK: - Property

    private(set) var currentError: PresentableError?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AppProduct",
        category: "ErrorHandler"
    )

    // MARK: - Init

    init() {}

    // MARK: - Public Methods

    func handle(_ error: Error, context: ErrorContext) {
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

    func clearError() {
        currentError = nil
    }

    // MARK: - Private Methods

    private func convert(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if let networkError = error as? NetworkError { return .network(networkError) }
        if let repositoryError = error as? RepositoryError { return .repository(repositoryError) }
        if let validationError = error as? ValidationError { return .validation(validationError) }
        if let authError = error as? AuthError { return .auth(authError) }
        if let domainError = error as? DomainError { return .domain(domainError) }
        if let urlError = error as? URLError { return .network(convertURLError(urlError)) }
        if let decodingError = error as? DecodingError {
            return .repository(.decodingError(detail: describeDecodingError(decodingError)))
        }
        if let generationError = error as? LanguageModelSession.GenerationError {
            return .domain(.custom(message: describeGenerationError(generationError)))
        }
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

    private func trackError(_ error: AppError, context: ErrorContext) {
        // TODO: Firebase Analytics, Sentry 등 연동 - [25.01.07] 이재원
    }

    // MARK: - Special Cases

    // TODO: [Refactor] NotificationCenter → AppState + Environment 패턴으로 리팩터링 예정 - [25.01.07] 이재원
    private func handleSpecialCases(_ error: AppError, context: ErrorContext) -> Bool {
        switch error {
        case .auth(.sessionExpired):
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            return true

        case .network(.unauthorized),
             .network(.tokenRefreshFailed),
             .network(.noRefreshToken),
             .network(.maxRetryExceeded):
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            return true

        case .auth(.pendingApproval):
            NotificationCenter.default.post(name: .navigateToPendingApproval, object: nil)
            return true

        default:
            return false
        }
    }
}
