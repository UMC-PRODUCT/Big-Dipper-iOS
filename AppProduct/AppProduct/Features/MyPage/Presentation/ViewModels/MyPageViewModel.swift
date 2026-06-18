//
//  MyPageViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/27/26.
//

import Foundation

/// MyPage 화면의 상태 및 비즈니스 로직을 관리하는 ViewModel
///
/// @Observable을 사용하여 SwiftUI View와 양방향 데이터 바인딩을 수행합니다.
/// 사용자 프로필 데이터와 Alert 상태를 관리합니다.
///
@Observable
class MyPageViewModel {
    // MARK: - Property

    /// 사용자 프로필 데이터를 담는 Loadable 상태
    private(set) var profileData: Loadable<ProfileData> = .idle

    /// Alert 표시를 위한 프롬프트 상태
    var alertPrompt: AlertPrompt?
    /// 카카오 소셜 로그인 매니저 (연동 시 OAuth 토큰 발급용)
    private let kakaoLoginManager = KakaoLoginManager()
    /// 애플 소셜 로그인 매니저 (연동 시 authorization code 발급용)
    private let appleLoginManager = AppleLoginManager()
    /// 구글 소셜 로그인 매니저 (연동 시 OAuth accessToken 발급용)
    private let googleLoginManager = GoogleLoginManager()

    // MARK: - Init

    init() {}

    init(previewProfileData: ProfileData) {
        self.profileData = .loaded(previewProfileData)
    }

    // MARK: - Function

    /// 내 프로필을 조회합니다.
    ///
    /// DIContainer에서 MyPageUseCaseProviding을 resolve하여 프로필 데이터를 fetch합니다.
    /// 중복 호출을 방지하기 위해 이미 로딩 중이면 무시합니다.
    ///
    /// - Parameter container: UseCase를 resolve할 DIContainer
    @MainActor
    func fetchProfile(container: DIContainer) async {
        if profileData.isLoading {
            return
        }

        let previousState = profileData
        profileData = .loading

        do {
            let provider = container.resolve(MyPageUseCaseProviding.self)
            var profile = try await provider.fetchMyPageProfileUseCase.execute()

            // 소셜 연동 노출 기준은 /member-oauth/me 응답만 사용합니다.
            if let syncedConnections = await syncConnectedSocials(container: container) {
                profile.socialConnections = syncedConnections
            } else {
                profile.socialConnections = []
            }

            profileData = .loaded(profile)
        } catch is CancellationError {
            profileData = previousState
        } catch let error as AppError {
            profileData = .failed(error)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            profileData = previousState
        } catch {
            profileData = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

    /// /member-oauth/me를 조회해 연동 소셜 목록을 동기화합니다.
    @MainActor
    private func syncConnectedSocials(
        container: DIContainer
    ) async -> [SocialConnection]? {
        do {
            let authProvider = container.resolve(AuthUseCaseProviding.self)
            let oauths = try await authProvider.fetchMyOAuthUseCase.execute()
            let connections = oauths.compactMap(Self.makeSocialConnection(from:))
            SocialType.saveConnected(connections.map(\.socialType))
            return connections
        } catch {
            return nil
        }
    }

    /// 소셜 계정 연동을 수행합니다.
    ///
    /// 소셜 로그인으로 OAuth verification token을 얻은 뒤
    /// `/api/v1/member-oauth` 연동 추가 API를 호출합니다.
    ///
    /// - Parameters:
    ///   - social: 연동할 소셜 타입 (kakao, apple)
    ///   - container: UseCase를 resolve할 DIContainer
    /// - Throws: 소셜 로그인 실패 또는 서버 연동 에러
    @MainActor
    func connectSocial(
        _ social: SocialType,
        container: DIContainer
    ) async throws {
        let authProvider = container.resolve(AuthUseCaseProviding.self)

        let verificationToken = try await fetchOAuthVerificationToken(
            social: social,
            authProvider: authProvider
        )

        let linked = try await authProvider.addMemberOAuthUseCase.execute(
            oAuthVerificationToken: verificationToken
        )

        let connected = linked.compactMap(Self.makeSocialConnection(from:))
        SocialType.saveConnected(connected.map(\.socialType))

        if case .loaded(var profile) = profileData {
            profile.socialConnections = connected
            profileData = .loaded(profile)
        }
    }

    // MARK: - Private Function

    /// 소셜 타입별 OAuth 로그인을 수행하여 verification token을 반환합니다.
    ///
    /// - Parameters:
    ///   - social: 로그인할 소셜 타입
    ///   - authProvider: 로그인 UseCase를 제공하는 Provider
    /// - Returns: 서버에서 발급한 OAuth verification token
    /// - Throws: `AuthError.socialLoginFailed` 기존 회원이거나 토큰이 비어있는 경우
    @MainActor
    private func fetchOAuthVerificationToken(
        social: SocialType,
        authProvider: AuthUseCaseProviding
    ) async throws -> String {
        let result: OAuthLoginResult

        switch social {
        case .kakao:
            let (accessToken, email) = try await kakaoLoginManager.login()
            result = try await authProvider.loginUseCase.executeKakao(
                accessToken: accessToken,
                email: email
            )

        case .apple:
            let authorizationCode = try await fetchAppleAuthorizationCode()
            result = try await authProvider.loginUseCase.executeApple(
                authorizationCode: authorizationCode,
                email: nil,
                fullName: nil
            )
        case .google:
            let accessToken = try await googleLoginManager.fetchAccessToken()
            result = try await authProvider.loginUseCase.executeGoogle(
                accessToken: accessToken
            )
        case .email:
            throw AuthError.socialLoginFailed(
                provider: social.rawValue,
                reason: "이메일 로그인은 OAuth 연동 추가 흐름의 대상이 아닙니다."
            )
        }

        return try extractVerificationToken(
            from: result,
            providerName: social.rawValue
        )
    }

    /// AppleLoginManager의 콜백을 async/await로 브릿징하여 authorization code를 반환합니다.
    @MainActor
    private func fetchAppleAuthorizationCode() async throws -> String {
        // 콜백 기반 API를 CheckedContinuation으로 변환
        try await withCheckedThrowingContinuation { continuation in
            appleLoginManager.onAuthorizationCompleted = { code, _, _ in
                continuation.resume(returning: code)
            }
            appleLoginManager.signWithApple()
        }
    }

    /// OAuthLoginResult에서 verification token을 추출합니다.
    ///
    /// - Note: newMember 상태에서만 verification token이 존재합니다.
    ///   existingMember는 이미 가입된 계정이므로 연동 불가로 에러를 던집니다.
    private func extractVerificationToken(
        from result: OAuthLoginResult,
        providerName: String
    ) throws -> String {
        switch result {
        case .newMember(let token) where !token.isEmpty:
            return token
        case .newMember:
            throw AuthError.socialLoginFailed(
                provider: providerName,
                reason: "OAuth 검증 토큰이 비어있습니다."
            )
        case .existingMember:
            throw AuthError.socialLoginFailed(
                provider: providerName,
                reason: "이미 연동된 계정이거나 연동 가능한 검증 토큰이 없습니다."
            )
        }
    }

    private static func makeSocialConnection(
        from memberOAuth: MemberOAuth
    ) -> SocialConnection? {
        guard let socialType = memberOAuth.provider.socialType else {
            return nil
        }

        return SocialConnection(
            memberOAuthId: memberOAuth.memberOAuthId,
            socialType: socialType
        )
    }
}
