//
//  EmailLoginViewModel.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/31/26.
//

import AuthDomain
import CoreDI
import CoreDomain
import Foundation
import UMCFoundation

/// 이메일(ID/PW) 로그인 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 핵심규칙 #1에 따라 `@Observable`을 사용한다. 로그인 성공 이후의 승인 상태 확인은
/// 소셜 로그인(`LoginViewModel.resolveApprovalStatus()`)과 동일한 규약을 따른다.
/// 인증 실패(잘못된 이메일/비밀번호)는 화면 내에서 해결 가능한 상태이므로 `ErrorHandler`
/// Alert이 아닌 인라인 메시지 + `Loadable.failed`로 표현한다.
///
/// - Note: 자동로그인 토글은 두지 않는다. `SyncProfileStorageUseCase`가
///   `canAutoLogin = profile.isApproved`를 단독으로 소유하며 소셜 로그인도 동일하다.
@Observable
final class EmailLoginViewModel {

    // MARK: - Constant

    private enum Constants {
        static let emailRequiredMessage: String = "이메일을 입력해 주세요."
        static let passwordRequiredMessage: String = "비밀번호를 입력해 주세요."
        static let invalidEmailFormatMessage: String = "이메일 형식이 올바르지 않습니다."
        static let invalidCredentialMessage: String = "이메일 또는 비밀번호가 올바르지 않습니다."
        static let invalidEmailFormatCode: String = "AUTHENTICATION-0025"
        static let invalidCredentialCode: String = "AUTHENTICATION-0022"
        static let action: String = "loginWithEmail"
    }

    // MARK: - Property

    private let loginByEmailUseCase: LoginByEmailUseCaseProtocol
    private let fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol
    private let syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// 이메일 입력값
    var emailInput: String = ""

    /// 비밀번호 입력값
    var passwordInput: String = ""

    /// 이메일 로그인 진행 상태. `.loaded`는 승인된 회원의 로그인 성공을 의미한다.
    private(set) var loginState: Loadable<Profile> = .idle

    /// 인증 실패 인라인 메시지
    private(set) var loginErrorMessage: String?

    /// 이메일 필드 입력 가이드 메시지
    private(set) var emailGuideMessage: String?

    /// 비밀번호 필드 입력 가이드 메시지
    private(set) var passwordGuideMessage: String?

    // MARK: - Init

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.loginByEmailUseCase = container.resolve(LoginByEmailUseCaseProtocol.self)
        self.fetchMemberProfileUseCase = container.resolve(FetchMemberProfileUseCaseProtocol.self)
        self.syncProfileStorageUseCase = container.resolve(SyncProfileStorageUseCaseProtocol.self)
        self.errorHandler = errorHandler
    }

    // MARK: - Computed Property

    /// 로그인 버튼 활성화 조건.
    ///
    /// `loginWithEmail()`의 빈 입력 검증과 동일한 기준이라 비활성 상태와 실제 제출 가능
    /// 여부가 항상 일치한다.
    var canSubmit: Bool {
        !emailInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !passwordInput.isEmpty
    }

    // MARK: - Function

    @MainActor
    func clearEmailGuide() {
        emailGuideMessage = nil
    }

    @MainActor
    func clearPasswordGuide() {
        passwordGuideMessage = nil
    }

    /// 이메일 로그인 실행 — 성공 시 승인 상태까지 확인해 `loginState`를 확정한다.
    @MainActor
    func loginWithEmail() async {
        guard !loginState.isLoading else { return }

        let email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordInput

        emailGuideMessage = email.isEmpty ? Constants.emailRequiredMessage : nil
        passwordGuideMessage = password.isEmpty ? Constants.passwordRequiredMessage : nil
        guard !email.isEmpty, !password.isEmpty else { return }

        loginState = .loading
        loginErrorMessage = nil

        do {
            _ = try await loginByEmailUseCase.execute(email: email, password: password)
            await resolveApprovalStatus()
        } catch let error as RepositoryError {
            handleLoginError(error)
        } catch let error as AppError {
            guard case .repository(let repositoryError) = error else {
                handleUnexpectedFailure(error)
                return
            }
            handleLoginError(repositoryError)
        } catch {
            handleUnexpectedFailure(error)
        }
    }

    // MARK: - Private Function

    /// 로그인 성공 직후 프로필을 조회해 승인 여부를 확정한다.
    ///
    /// 미승인 회원은 `.failed(.auth(.pendingApproval))`로 화면에 남고, 승인 회원만
    /// 로컬 저장소를 동기화한 뒤 `.loaded`로 전환된다
    /// (`LoginViewModel.resolveApprovalStatus()`와 동일 규약).
    @MainActor
    private func resolveApprovalStatus() async {
        do {
            let profile = try await fetchMemberProfileUseCase.execute()
            guard profile.isApproved else {
                loginState = .failed(.auth(.pendingApproval))
                return
            }
            syncProfileStorageUseCase.execute(profile: profile)
            loginState = .loaded(profile)
        } catch {
            loginState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Auth",
                action: Constants.action,
                retryAction: { [weak self] in await self?.resolveApprovalStatus() }
            ))
        }
    }

    /// 서버 인증 실패를 인라인 메시지로 변환한다.
    @MainActor
    private func handleLoginError(_ error: RepositoryError) {
        if case .serverError(let code, let message) = error {
            switch code {
            case Constants.invalidEmailFormatCode:
                loginErrorMessage = Constants.invalidEmailFormatMessage
            case Constants.invalidCredentialCode:
                loginErrorMessage = Constants.invalidCredentialMessage
            default:
                if let message, !message.isEmpty {
                    loginErrorMessage = message
                } else {
                    loginErrorMessage = Constants.invalidCredentialMessage
                }
            }
        } else {
            loginErrorMessage = Constants.invalidCredentialMessage
        }
        loginState = .failed(.repository(error))
    }

    @MainActor
    private func handleUnexpectedFailure(_ error: Error) {
        loginState = .idle
        errorHandler.handle(error, context: ErrorContext(
            feature: "Auth",
            action: Constants.action,
            retryAction: { [weak self] in await self?.loginWithEmail() }
        ))
    }
}
