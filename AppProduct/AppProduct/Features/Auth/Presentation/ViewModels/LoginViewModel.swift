//
//  LoginViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import Foundation

/// 로그인 화면의 상태 및 액션을 관리하는 ViewModel
@Observable
final class LoginViewModel {

    // MARK: - Property

    private let loginUseCase: LoginUseCaseProtocol
    private let loginByIdPwUseCase: LoginByIdPwUseCaseProtocol
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    private let kakaoLoginManager: KakaoLoginManager
    private let appleLoginManager: AppleLoginManager
    private let tokenStore: TokenStore
    private let errorHandler: ErrorHandler

    /// 로그인 상태 (OAuth)
    private(set) var loginState: Loadable<OAuthLoginResult> = .idle
    /// 로그인 상태 (ID/PW)
    private(set) var loginByIdPwState: Loadable<LoginByIdPwResult> = .idle
    /// 로그인 후 이동할 목적지
    private(set) var destination: LoginDestination?

    /// ID/PW 입력 — 로그인 ID
    var loginIdInput: String = ""
    /// ID/PW 입력 — 비밀번호
    var passwordInput: String = ""
    /// ID/PW 로그인 인라인 에러 메시지 (네트워크 오류 등 Alert는 errorHandler 사용)
    private(set) var loginByIdPwErrorMessage: String?

    // MARK: - Init

    init(
        loginUseCase: LoginUseCaseProtocol,
        loginByIdPwUseCase: LoginByIdPwUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler,
        kakaoLoginManager: KakaoLoginManager = KakaoLoginManager(),
        appleLoginManager: AppleLoginManager = AppleLoginManager()
    ) {
        self.loginUseCase = loginUseCase
        self.loginByIdPwUseCase = loginByIdPwUseCase
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
        self.tokenStore = tokenStore
        self.errorHandler = errorHandler
        self.kakaoLoginManager = kakaoLoginManager
        self.appleLoginManager = appleLoginManager
    }

    // MARK: - Function

    /// 카카오 로그인 실행
    @MainActor
    func loginWithKakao() async {
        loginState = .loading
        destination = nil

        do {
            let (accessToken, email) = try await kakaoLoginManager.login()
            #if DEBUG
            print("[Auth] 카카오 accessToken: \(accessToken)")
            print("[Auth] 카카오 email: \(email)")
            #endif
            let result = try await loginUseCase.executeKakao(
                accessToken: accessToken,
                email: email
            )
            SocialType.addConnected(.kakao)
            #if DEBUG
            print("[Auth] 서버 로그인 결과: \(result)")
            #endif
            loginState = .loaded(result)
            destination = try await resolveDestination(
                from: result,
                postRegisterLoginContext: .kakao(
                    accessToken: accessToken,
                    email: email
                )
            )
        } catch {
            loginState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Auth",
                action: "loginWithKakao",
                retryAction: { [weak self] in
                    await self?.loginWithKakao()
                }
            ))
        }
    }

    /// ID/PW 로그인 실행
    @MainActor
    func loginWithIdPw() async {
        let trimmedId = loginIdInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedPw = passwordInput

        guard !trimmedId.isEmpty, !trimmedPw.isEmpty else {
            loginByIdPwErrorMessage = "아이디와 비밀번호를 입력해주세요."
            return
        }

        loginByIdPwState = .loading
        loginByIdPwErrorMessage = nil
        destination = nil

        do {
            let result = try await loginByIdPwUseCase.execute(
                loginId: trimmedId,
                password: trimmedPw
            )
            loginByIdPwState = .loaded(result)

            let profile = try await fetchMyProfileUseCase.execute()
            let isApproved = isApprovedProfile(profile)
            UserDefaults.standard.set(
                isApproved,
                forKey: AppStorageKey.canAutoLogin
            )
            destination = isApproved ? .main : .pendingApproval
        } catch let error as RepositoryError {
            handleIdPwError(error)
        } catch let error as AppError {
            switch error {
            case .repository(let repositoryError):
                handleIdPwError(repositoryError)
            default:
                loginByIdPwState = .idle
                errorHandler.handle(error, context: .init(
                    feature: "Auth",
                    action: "loginWithIdPw",
                    retryAction: { [weak self] in
                        await self?.loginWithIdPw()
                    }
                ))
            }
        } catch {
            loginByIdPwState = .idle
            errorHandler.handle(error, context: .init(
                feature: "Auth",
                action: "loginWithIdPw",
                retryAction: { [weak self] in
                    await self?.loginWithIdPw()
                }
            ))
        }
    }

    /// Apple 로그인 실행
    @MainActor
    func loginWithApple() {
        loginState = .loading
        destination = nil

        appleLoginManager.onAuthorizationCompleted = {
            [weak self] code, email, fullName in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let result = try await self.loginUseCase.executeApple(
                        authorizationCode: code,
                        email: email,
                        fullName: fullName
                    )
                    SocialType.addConnected(.apple)
                    self.loginState = .loaded(result)
                    self.destination = try await self.resolveDestination(
                        from: result,
                        email: email,
                        fullName: fullName,
                        postRegisterLoginContext: .apple(
                            authorizationCode: code,
                            email: email,
                            fullName: fullName
                        )
                    )
                } catch {
                    self.loginState = .idle
                    self.errorHandler.handle(
                        error,
                        context: ErrorContext(
                            feature: "Auth",
                            action: "loginWithApple",
                            retryAction: { [weak self] in
                                self?.loginWithApple()
                            }
                        )
                    )
                }
            }
        }

        appleLoginManager.signWithApple()
    }
}

// MARK: - Private

private extension LoginViewModel {
    /// ID/PW 로그인 도메인 에러를 인라인 메시지로 변환합니다.
    @MainActor
    func handleIdPwError(_ error: RepositoryError) {
        if case .serverError(_, let message) = error,
           let message,
           !message.isEmpty {
            loginByIdPwErrorMessage = message
        } else {
            loginByIdPwErrorMessage = "아이디 또는 비밀번호가 올바르지 않습니다."
        }
        loginByIdPwState = .failed(.repository(error))
    }

    /// 로그인 결과를 기반으로 최종 이동 목적지를 계산합니다.
    func resolveDestination(
        from result: OAuthLoginResult,
        email: String? = nil,
        fullName: String? = nil,
        postRegisterLoginContext: PostRegisterLoginContext? = nil
    ) async throws -> LoginDestination {
        switch result {
        case .newMember(let verificationToken):
            UserDefaults.standard.set(
                false,
                forKey: AppStorageKey.canAutoLogin
            )
            return .signUp(
                verificationToken: verificationToken,
                email: email,
                fullName: fullName,
                postRegisterLoginContext: postRegisterLoginContext
            )

        case .existingMember(let tokenPair):
            try await ensureTokensStored(tokenPair)
            let profile = try await fetchMyProfileUseCase.execute()
            let isApproved = isApprovedProfile(profile)
            UserDefaults.standard.set(
                isApproved,
                forKey: AppStorageKey.canAutoLogin
            )
            return isApproved ? .main : .pendingApproval
        }
    }

    func ensureTokensStored(_ tokenPair: TokenPair) async throws {
        let accessToken = tokenPair.accessToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let refreshToken = tokenPair.refreshToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !accessToken.isEmpty, !refreshToken.isEmpty else {
            return
        }

        let savedAccessToken = await tokenStore.getAccessToken()
        let savedRefreshToken = await tokenStore.getRefreshToken()

        guard savedAccessToken != accessToken || savedRefreshToken != refreshToken else {
            return
        }

        try await tokenStore.save(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    func isApprovedProfile(_ profile: HomeProfileResult) -> Bool {
        if !profile.generations.isEmpty {
            return true
        }

        for seasonType in profile.seasonTypes {
            if case .gens(let generations) = seasonType, !generations.isEmpty {
                return true
            }
        }

        return false
    }
}

// MARK: - LoginDestination

/// 로그인 완료 후 이동할 화면 목적지
enum LoginDestination: Equatable {
    case main
    case pendingApproval
    case signUp(
        verificationToken: String,
        email: String?,
        fullName: String?,
        postRegisterLoginContext: PostRegisterLoginContext?
    )
}
