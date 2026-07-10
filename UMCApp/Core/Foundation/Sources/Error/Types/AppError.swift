//
//  AppError.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation

/// 앱 전체에서 사용하는 통합 에러 타입.
///
/// 모든 에러를 래핑하여 일관된 처리를 제공합니다.
/// ViewModel에서 에러 발생 시 이 타입으로 변환하여 처리합니다.
///
/// ## Usage
///
/// **ViewModel에서 에러 타입별 분기 처리:**
///
/// ```swift
/// @MainActor
/// func submit() async {
///     state = .loading
///
///     do {
///         let result = try await useCase.execute()
///         state = .loaded(result)
///
///     } catch let error as DomainError {
///         // 도메인 에러 → Loadable
///         state = .failed(.domain(error))
///
///     } catch {
///         // 기타 에러 → ErrorHandler (Alert) + 상태 복구
///         state = .loaded(initialData)
///         errorHandler.handle(error, context: .init(
///             feature: "Feature",
///             action: "submit",
///             retryAction: { [weak self] in await self?.submit() }
///         ))
///     }
/// }
/// ```
///
/// **View에서 인라인 에러 표시:**
///
/// ```swift
/// if let error = viewModel.state.error {
///     Text(error.userMessage)
///         .foregroundStyle(.red)
/// }
/// ```
///
/// - SeeAlso: ``ErrorHandler``, ``Loadable``, ``DomainError``
public enum AppError: Error, LocalizedError, Equatable {
    /// Repository 계층 에러 (서버 비즈니스 에러)
    case repository(RepositoryError)

    /// 네트워크 계층 에러 (Actor 기반 NetworkClient)
    case network(NetworkError)

    /// 입력 유효성 검증 에러
    case validation(ValidationError)

    /// 인증 관련 에러
    case auth(AuthError)

    /// 도메인(비즈니스) 에러
    case domain(DomainError)

    /// 알 수 없는 에러
    case unknown(message: String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .repository(let error):
            return error.errorDescription
        case .network(let error):
            return error.errorDescription
        case .validation(let error):
            return error.errorDescription
        case .auth(let error):
            return error.errorDescription
        case .domain(let error):
            return error.errorDescription
        case .unknown(let message):
            return message
        }
    }

    // MARK: - User Message

    /// 사용자에게 표시할 친화적 메시지
    public var userMessage: String {
        switch self {
        case .repository(let error):
            return error.userMessage
        case .network(let error):
            return error.userMessage
        case .validation(let error):
            return error.userMessage
        case .auth(let error):
            return error.userMessage
        case .domain(let error):
            return error.userMessage
        case .unknown:
            return "일시적인 오류가 발생했습니다. 다시 시도해주세요."
        }
    }

    // MARK: - Severity

    /// 에러 심각도 (표시 방식 결정에 사용)
    public var severity: ErrorSeverity {
        switch self {
        case .repository:
            return .warning
        case .network(let error):
            return error.severity
        case .validation:
            return .warning
        case .auth:
            return .critical
        case .domain:
            return .info
        case .unknown:
            return .warning
        }
    }

    // MARK: - Retryable

    /// 재시도 가능 여부
    public var isRetryable: Bool {
        switch self {
        case .repository(let error):
            return error.isRetryable
        case .network(let error):
            return error.isRetryable
        case .validation:
            return false
        case .auth:
            return false
        case .domain:
            return false
        case .unknown:
            return true
        }
    }

    // MARK: - Factory

    /// 임의의 `Error`를 공통 규칙으로 `AppError`로 정규화한다.
    ///
    /// 여러 ViewModel(예: `SignUpViewModel`, `SignUpByIdPwViewModel`)이 각자
    /// `catch` 블록에서 동일한 `RepositoryError`/`NetworkError`/`AuthError` 매핑 로직을
    /// 중복 구현하던 것을 통합한 지점이다. 이미 `AppError`인 경우 그대로 반환하고,
    /// 알려진 하위 에러 타입이 아니면 `.unknown`으로 폴백한다.
    public static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let repositoryError = error as? RepositoryError {
            return .repository(repositoryError)
        }
        if let networkError = error as? NetworkError {
            return .network(networkError)
        }
        if let authError = error as? AuthError {
            return .auth(authError)
        }
        return .unknown(message: error.localizedDescription)
    }
}
