//
//  LoginViewModel.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/9/26.
//

import AuthDomain
import CoreDI
import CoreDomain
import CoreNetwork
import Foundation
import UMCFoundation

/// 신규 회원 소셜 로그인 시 회원가입 화면으로 전환하기 위한 목적지 정보.
///
/// `LoginView`가 이 값을 관찰해 `appFlow.showSignUp(...)`을 호출한다. `postRegisterLoginContext`는
/// 가입 완료 후 서버가 세션을 확립해주지 않을 때 재로그인에 사용된다(레거시 `resolveDestination` 대응).
struct SignUpDestination: Equatable {
    let verificationToken: String
    let email: String?
    let fullName: String?
    let postRegisterLoginContext: PostRegisterLoginContext?
}

/// 소셜 로그인 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 핵심규칙 #1에 따라 `@Observable`을 사용한다. 신규 회원 결과는 `signUpDestination`을 통해
/// 노출되어 `LoginView`가 회원가입 화면으로 전환하고, 승인 대기 회원은
/// `Loadable.failed(.auth(.pendingApproval))`로 화면에 머무르며 안내 문구를 노출한다.
@Observable
final class LoginViewModel {

    // MARK: - Property

    private let loginUseCase: LoginUseCaseProtocol
    private let fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol
    private let syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol
    private let errorHandler: ErrorHandler

    private let kakaoLoginManager: KakaoLoginManaging
    private let appleLoginManager: AppleLoginManaging
    private let googleLoginManager: GoogleLoginManaging

    /// 소셜 로그인 진행 상태. `.loaded`는 승인된 기존 회원 로그인 성공을 의미한다.
    var loginState: Loadable<Profile> = .idle
    /// 신규 회원(가입 필요) 판정 시 노출되는 회원가입 화면 목적지.
    var signUpDestination: SignUpDestination?

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        kakaoLoginManager: KakaoLoginManaging = KakaoLoginManager(),
        appleLoginManager: AppleLoginManaging = AppleLoginManager(),
        googleLoginManager: GoogleLoginManaging = GoogleLoginManager()
    ) {
        self.loginUseCase = container.resolve(LoginUseCaseProtocol.self)
        self.fetchMemberProfileUseCase = container.resolve(FetchMemberProfileUseCaseProtocol.self)
        self.syncProfileStorageUseCase = container.resolve(SyncProfileStorageUseCaseProtocol.self)
        self.errorHandler = errorHandler
        self.kakaoLoginManager = kakaoLoginManager
        self.appleLoginManager = appleLoginManager
        self.googleLoginManager = googleLoginManager
    }

    // MARK: - Function

    @MainActor
    func loginWithKakao() async {
        guard !loginState.isLoading else { return }
        loginState = .loading

        do {
            let (accessToken, email) = try await kakaoLoginManager.login()
            let result = try await loginUseCase.executeKakao(
                accessToken: accessToken,
                email: email
            )
            SocialType.addConnected(.kakao)
            await handle(
                result: result,
                action: "loginWithKakao",
                prefillEmail: email,
                prefillFullName: nil,
                postRegisterLoginContext: .kakao(accessToken: accessToken, email: email)
            )
        } catch {
            handleFailure(error, action: "loginWithKakao") { [weak self] in
                await self?.loginWithKakao()
            }
        }
    }

    /// Apple 로그인 실행.
    ///
    /// `AppleLoginManager`는 delegate 콜백 기반이라 다른 두 로그인과 달리 async 함수가 아니다.
    @MainActor
    func loginWithApple() {
        guard !loginState.isLoading else { return }
        loginState = .loading

        appleLoginManager.onAuthorizationFailed = { [weak self] error in
            Task { @MainActor in
                self?.handleFailure(error, action: "loginWithApple") { [weak self] in
                    self?.loginWithApple()
                }
            }
        }

        appleLoginManager.onAuthorizationCompleted = { [weak self] code, email, fullName in
            Task { @MainActor in
                await self?.completeAppleLogin(
                    authorizationCode: code,
                    email: email,
                    fullName: fullName
                )
            }
        }

        appleLoginManager.signWithApple()
    }

    @MainActor
    func loginWithGoogle() async {
        guard !loginState.isLoading else { return }
        loginState = .loading

        do {
            let (accessToken, email) = try await googleLoginManager.login()
            let result = try await loginUseCase.executeGoogle(accessToken: accessToken)
            SocialType.addConnected(.google)
            await handle(
                result: result,
                action: "loginWithGoogle",
                prefillEmail: email,
                prefillFullName: nil,
                postRegisterLoginContext: .google(accessToken: accessToken)
            )
        } catch {
            handleFailure(error, action: "loginWithGoogle") { [weak self] in
                await self?.loginWithGoogle()
            }
        }
    }

    // MARK: - Private Function

    @MainActor
    private func completeAppleLogin(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async {
        do {
            let result = try await loginUseCase.executeApple(
                authorizationCode: authorizationCode,
                email: email,
                fullName: fullName
            )
            SocialType.addConnected(.apple)
            await handle(
                result: result,
                action: "loginWithApple",
                prefillEmail: email,
                prefillFullName: fullName,
                postRegisterLoginContext: .apple(
                    authorizationCode: authorizationCode,
                    email: email,
                    fullName: fullName
                )
            )
        } catch {
            handleFailure(error, action: "loginWithApple") { [weak self] in
                self?.loginWithApple()
            }
        }
    }

    @MainActor
    private func handle(
        result: OAuthLoginResult,
        action: String,
        prefillEmail: String?,
        prefillFullName: String?,
        postRegisterLoginContext: PostRegisterLoginContext
    ) async {
        switch result {
        case .newMember(let verificationToken):
            presentSignUpDestination(
                verificationToken: verificationToken,
                email: prefillEmail,
                fullName: prefillFullName,
                postRegisterLoginContext: postRegisterLoginContext
            )
        case .existingMember:
            await resolveApprovalStatus(action: action)
        }
    }

    @MainActor
    private func resolveApprovalStatus(action: String) async {
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
                action: action,
                retryAction: { [weak self] in
                    await self?.resolveApprovalStatus(action: action)
                }
            ))
        }
    }

    /// 신규 회원 판정 결과를 회원가입 화면 목적지로 노출한다.
    ///
    /// `LoginView`가 `signUpDestination`을 관찰해 `appFlow.showSignUp(...)`을 호출한다.
    @MainActor
    private func presentSignUpDestination(
        verificationToken: String,
        email: String?,
        fullName: String?,
        postRegisterLoginContext: PostRegisterLoginContext
    ) {
        loginState = .idle
        signUpDestination = SignUpDestination(
            verificationToken: verificationToken,
            email: email,
            fullName: fullName,
            postRegisterLoginContext: postRegisterLoginContext
        )
    }

    @MainActor
    private func handleFailure(
        _ error: Error,
        action: String,
        retryAction: (() async -> Void)?
    ) {
        loginState = .idle
        // 사용자가 로그인 시트를 취소한 경우는 에러가 아니므로 알럿을 띄우지 않는다.
        guard (error as? SocialLoginError) != .cancelled else { return }
        errorHandler.handle(error, context: ErrorContext(
            feature: "Auth",
            action: action,
            retryAction: retryAction
        ))
    }
}
