//
//  LoginByIdPwViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/14/26.
//

import Foundation

/// 이메일 로그인 화면의 상태 및 액션을 관리하는 ViewModel
@Observable
final class LoginByIdPwViewModel {

    // MARK: - Property

    private let loginByEmailUseCase: LoginByEmailUseCaseProtocol
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    private let tokenStore: TokenStore
    private let errorHandler: ErrorHandler

    /// 이메일 로그인 진행 상태
    private(set) var loginByEmailState: Loadable<LoginByIdPwResult> = .idle
    /// 인라인 에러 메시지 (도메인/유효성 오류)
    private(set) var loginErrorMessage: String?
    /// 이메일 필드 유효성 가이드 메시지
    private(set) var emailGuideMessage: String?
    /// 비밀번호 필드 유효성 가이드 메시지
    private(set) var passwordGuideMessage: String?
    /// 로그인 완료 후 이동할 목적지
    private(set) var destination: IdPwLoginDestination?

    /// 이메일 입력값
    var emailInput: String = ""
    /// 비밀번호 입력값
    var passwordInput: String = ""
    /// 자동로그인 활성화 여부
    var isAutoLoginEnabled: Bool = false

    // MARK: - Init

    init(
        loginByEmailUseCase: LoginByEmailUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler
    ) {
        self.loginByEmailUseCase = loginByEmailUseCase
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
        self.tokenStore = tokenStore
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    func clearEmailGuide() {
        emailGuideMessage = nil
    }

    func clearPasswordGuide() {
        passwordGuideMessage = nil
    }

    /// 이메일 로그인 실행
    @MainActor
    func loginWithEmail() async {
        let trimmedEmail = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPw = passwordInput

        emailGuideMessage = trimmedEmail.isEmpty ? "이메일을 입력해 주세요." : nil
        passwordGuideMessage = trimmedPw.isEmpty ? "비밀번호를 입력해 주세요." : nil

        guard !trimmedEmail.isEmpty, !trimmedPw.isEmpty else {
            return
        }

        loginByEmailState = .loading
        loginErrorMessage = nil
        emailGuideMessage = nil
        passwordGuideMessage = nil
        destination = nil

        do {
            let result = try await loginByEmailUseCase.execute(
                email: trimmedEmail,
                password: trimmedPw
            )
            try await ensureTokensStored(result.tokenPair)
            loginByEmailState = .loaded(result)

            let profile = try await fetchMyProfileUseCase.execute()
            let isApproved = isApprovedProfile(profile)

            UserDefaults.standard.set(
                isApproved && isAutoLoginEnabled,
                forKey: AppStorageKey.canAutoLogin
            )
            destination = isApproved ? .main : .pendingApproval
        } catch let error as RepositoryError {
            handleLoginError(error)
        } catch let error as AppError {
            switch error {
            case .repository(let repositoryError):
                handleLoginError(repositoryError)
            default:
                loginByEmailState = .idle
                errorHandler.handle(error, context: .init(
                    feature: "Auth",
                    action: "loginWithEmail",
                    retryAction: { [weak self] in
                        await self?.loginWithEmail()
                    }
                ))
            }
        } catch {
            loginByEmailState = .idle
            errorHandler.handle(error, context: .init(
                feature: "Auth",
                action: "loginWithEmail",
                retryAction: { [weak self] in
                    await self?.loginWithEmail()
                }
            ))
        }
    }
}

// MARK: - Private

private extension LoginByIdPwViewModel {
    /// 이메일 로그인 도메인 에러를 인라인 메시지로 변환합니다.
    @MainActor
    func handleLoginError(_ error: RepositoryError) {
        if case .serverError(let code, let message) = error {
            switch code {
            case "AUTHENTICATION-0025":
                loginErrorMessage = "이메일 형식이 올바르지 않습니다."
            case "AUTHENTICATION-0022":
                loginErrorMessage = "이메일 또는 비밀번호가 올바르지 않습니다."
            default:
                if let message, !message.isEmpty {
                    loginErrorMessage = message
                } else {
                    loginErrorMessage = "이메일 또는 비밀번호가 올바르지 않습니다."
                }
            }
        } else {
            loginErrorMessage = "이메일 또는 비밀번호가 올바르지 않습니다."
        }
        loginByEmailState = .failed(.repository(error))
    }

    func ensureTokensStored(_ tokenPair: TokenPair) async throws {
        let accessToken = tokenPair.accessToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let refreshToken = tokenPair.refreshToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !accessToken.isEmpty, !refreshToken.isEmpty else { return }

        let savedAccessToken = await tokenStore.getAccessToken()
        let savedRefreshToken = await tokenStore.getRefreshToken()

        guard savedAccessToken != accessToken || savedRefreshToken != refreshToken else {
            return
        }

        try await tokenStore.save(accessToken: accessToken, refreshToken: refreshToken)
    }

    func isApprovedProfile(_ profile: HomeProfileResult) -> Bool {
        if !profile.generations.isEmpty { return true }
        for seasonType in profile.seasonTypes {
            if case .gens(let generations) = seasonType, !generations.isEmpty {
                return true
            }
        }
        return false
    }
}

// MARK: - IdPwLoginDestination

/// 이메일 로그인 완료 후 이동할 화면 목적지
enum IdPwLoginDestination: Equatable {
    case main
    case pendingApproval
}
