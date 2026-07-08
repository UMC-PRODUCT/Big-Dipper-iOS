import AuthDomain
import CoreDI
import CoreNetwork
import Foundation
import UMCFoundation

/// 소셜 로그인 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 절대규칙 #1에 따라 `@Observable`을 사용한다. 이번 슬라이스는 기존 회원 로그인만
/// 다루므로 신규 회원 결과는 화면 전환 없이 안내만 하고(`TODO(#944)`), 승인 대기 회원은
/// `Loadable.failed(.auth(.pendingApproval))`로 화면에 머무르며 안내 문구를 노출한다.
@Observable
final class LoginViewModel {

    // MARK: - Property

    private let loginUseCase: LoginUseCaseProtocol
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    private let errorHandler: ErrorHandler

    private let kakaoLoginManager: KakaoLoginManaging
    private let appleLoginManager: AppleLoginManaging
    private let googleLoginManager: GoogleLoginManaging

    /// 소셜 로그인 진행 상태. `.loaded`는 승인된 기존 회원 로그인 성공을 의미한다.
    var loginState: Loadable<Profile> = .idle
    /// 신규 회원(가입 필요) 안내 다이얼로그.
    var alertPrompt: AlertPrompt?

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        kakaoLoginManager: KakaoLoginManaging = KakaoLoginManager(),
        appleLoginManager: AppleLoginManaging = AppleLoginManager(),
        googleLoginManager: GoogleLoginManaging = GoogleLoginManager()
    ) {
        self.loginUseCase = container.resolve(LoginUseCaseProtocol.self)
        self.fetchMyProfileUseCase = container.resolve(FetchMyProfileUseCaseProtocol.self)
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
            await handle(result: result, action: "loginWithKakao")
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
            let (accessToken, _) = try await googleLoginManager.login()
            let result = try await loginUseCase.executeGoogle(accessToken: accessToken)
            SocialType.addConnected(.google)
            await handle(result: result, action: "loginWithGoogle")
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
            await handle(result: result, action: "loginWithApple")
        } catch {
            handleFailure(error, action: "loginWithApple") { [weak self] in
                self?.loginWithApple()
            }
        }
    }

    @MainActor
    private func handle(result: OAuthLoginResult, action: String) async {
        switch result {
        case .newMember:
            presentNewMemberGuidance()
        case .existingMember:
            await resolveApprovalStatus(action: action)
        }
    }

    @MainActor
    private func resolveApprovalStatus(action: String) async {
        do {
            let profile = try await fetchMyProfileUseCase.execute()
            loginState = profile.isApproved ? .loaded(profile) : .failed(.auth(.pendingApproval))
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

    /// 신규 회원 결과 안내.
    ///
    /// - Note: TODO(#944) 회원가입 플로우가 구현되기 전까지, 신규 회원 소셜 로그인은
    ///   화면 전환 없이 안내 후 로그인 화면에 머무른다.
    @MainActor
    private func presentNewMemberGuidance() {
        loginState = .idle
        alertPrompt = AlertPrompt(
            title: "가입 절차가 준비 중이에요",
            message: "아직 지원하지 않는 신규 회원 가입 절차입니다. 운영진에게 문의해주세요.",
            positiveBtnTitle: "확인"
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
