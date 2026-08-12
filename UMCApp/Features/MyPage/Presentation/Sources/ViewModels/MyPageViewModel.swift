//
//  MyPageViewModel.swift
//  MyPagePresentation
//
//  Created by One on 5/24/26.
//

import AuthDomain
import CommunityDomain
import CoreDI
import CoreDomain
import CoreNetwork
import Foundation
import MyPageDomain
import UMCFoundation

/// MyPage 화면의 상태 및 비즈니스 로직을 관리하는 ViewModel.
///
/// `@Observable`을 사용하여 SwiftUI View와 양방향 데이터 바인딩을 수행합니다.
/// 사용자 프로필 데이터와 Alert 상태를 관리합니다.
@Observable
public final class MyPageViewModel {

    // MARK: - Property

    /// 사용자 프로필 데이터를 담는 Loadable 상태.
    public private(set) var profileData: Loadable<ProfileData> = .idle

    /// Alert 표시를 위한 프롬프트 상태 (확인/취소 다이얼로그).
    public var alertPrompt: AlertPrompt?

    private let container: DIContainer
    private let myPageProvider: MyPageUseCaseProviding
    private let fetchMyOAuthUseCase: FetchMyOAuthUseCaseProtocol
    private let addMemberOAuthUseCase: AddMemberOAuthUseCaseProtocol
    private let loginUseCase: LoginUseCaseProtocol
    private let kakaoLoginManager: KakaoLoginManaging
    private let appleLoginManager: AppleLoginManaging
    private let googleLoginManager: GoogleLoginManaging

    // MARK: - Init

    public init(
        container: DIContainer,
        kakaoLoginManager: KakaoLoginManaging = KakaoLoginManager(),
        appleLoginManager: AppleLoginManaging = AppleLoginManager(),
        googleLoginManager: GoogleLoginManaging = GoogleLoginManager()
    ) {
        self.container = container
        self.myPageProvider = container.resolve(MyPageUseCaseProviding.self)
        self.fetchMyOAuthUseCase = container.resolve(FetchMyOAuthUseCaseProtocol.self)
        self.addMemberOAuthUseCase = container.resolve(AddMemberOAuthUseCaseProtocol.self)
        self.loginUseCase = container.resolve(LoginUseCaseProtocol.self)
        self.kakaoLoginManager = kakaoLoginManager
        self.appleLoginManager = appleLoginManager
        self.googleLoginManager = googleLoginManager
    }

    #if DEBUG
    /// 프리뷰 전용 — 미리 로드된 프로필 상태로 시작합니다.
    public convenience init(container: DIContainer, previewProfileData: ProfileData) {
        self.init(container: container)
        self.profileData = .loaded(previewProfileData)
    }
    #endif

    // MARK: - Function

    /// 내 프로필을 조회합니다.
    ///
    /// 이미 로딩 중이면 중복 호출을 무시합니다. 에러 분기:
    /// - `CancellationError` / `NSURLErrorCancelled` → 이전 상태 복원
    /// - `AppError` → `.failed(error)`
    /// - 그 외 → `.failed(.unknown(message:))`
    ///
    /// - Parameter forceRefresh: `true`이면 세션 프로필 캐시를 우회해 서버 최신으로 갱신한다.
    @MainActor
    public func fetchProfile(forceRefresh: Bool = false) async {
        if profileData.isLoading { return }

        let previousState = profileData
        profileData = .loading

        do {
            var profile = try await myPageProvider.fetchMyPageProfileUseCase.execute(
                forceRefresh: forceRefresh
            )
            // 소셜 연동 노출 기준은 `/member-oauth/me` 응답만 사용한다.
            profile.socialConnections = await syncConnectedSocials() ?? []
            profileData = .loaded(profile)
        } catch is CancellationError {
            profileData = previousState
        } catch let error as AppError {
            profileData = .failed(error)
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            profileData = previousState
        } catch {
            profileData = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 소셜 계정 연동을 수행합니다.
    ///
    /// 소셜 로그인으로 OAuth 검증 토큰을 얻은 뒤 연동 추가 API를 호출하고,
    /// 응답으로 받은 전체 연동 목록을 프로필 상태에 반영합니다.
    ///
    /// - Parameter social: 연동할 소셜 타입
    /// - Throws: 소셜 로그인 실패 또는 서버 연동 에러
    @MainActor
    public func connectSocial(_ social: SocialType) async throws {
        let verificationToken = try await fetchOAuthVerificationToken(social: social)
        let linked = try await addMemberOAuthUseCase.execute(
            oAuthVerificationToken: verificationToken
        )

        let connected = linked.compactMap(SocialConnection.init(memberOAuth:))
        SocialType.saveConnected(connected.map(\.socialType))

        if case .loaded(var profile) = profileData {
            profile.socialConnections = connected
            profileData = .loaded(profile)
        }
    }

    /// 로그아웃을 수행합니다.
    ///
    /// 화면 전환(`AppFlow`)은 절대규칙 #1에 따라 View가 담당하므로, 여기서는 세션 정리까지만
    /// 책임지고 실패는 그대로 던져 호출자가 `ErrorHandler`로 넘기게 한다.
    @MainActor
    public func logout() async throws {
        UserDefaults.standard.set(false, forKey: AppStorageKey.canAutoLogin)
        try await tearDownSession()
    }

    /// 회원 탈퇴 후 세션을 정리합니다.
    @MainActor
    public func deleteAccount() async throws {
        try await myPageProvider.deleteMemberUseCase.execute()
        UserDefaults.standard.set(false, forKey: AppStorageKey.canAutoLogin)
        try await tearDownSession()
    }

    // MARK: - Private Function

    /// 토큰·세션 역할·프로필 캐시·STOMP 연결·DI 캐시를 차례로 비웁니다.
    ///
    /// `resetCache()`보다 먼저 참조를 확보하는 이유는 `AppRootView.handleAuthSessionExpired`와
    /// 같다 — 캐시를 비운 뒤 resolve하면 새 인스턴스가 만들어져 정리 대상이 어긋난다.
    ///
    /// STOMP 연결은 `resetCache()`가 참조를 버려도 펌프 Task가 클라이언트를 강참조해 살아남고,
    /// 생성 시점에 붙잡은 구 `TokenStore`의 인메모리 캐시로 로그아웃한 세션의 토큰을 계속
    /// 재사용한다. 그래서 캐시를 비우기 **전에** `stop()`을 끝까지 기다린다. 한 번도 만들어진
    /// 적이 없으면 `resolveIfCached`가 nil을 반환해 새 인스턴스를 만들지 않는다.
    @MainActor
    private func tearDownSession() async throws {
        let networkClient = container.resolve(NetworkClient.self)
        let memberProfileRepository = container.resolveIfRegistered(
            MemberProfileRepositoryProtocol.self
        )
        let communityRealtime = container.resolveIfCached(CommunityThreadRealtimeProtocol.self)
        let userSessionManager = container.resolve(UserSessionManager.self)

        try await networkClient.logout()
        userSessionManager.reset()
        await memberProfileRepository?.invalidateCache()
        await communityRealtime?.stop()
        container.resetCache()
    }

    /// `/member-oauth/me`를 조회해 연동 소셜 목록을 동기화합니다.
    ///
    /// 조회 실패는 프로필 조회 전체를 실패시키지 않고 `nil`을 반환합니다.
    @MainActor
    private func syncConnectedSocials() async -> [SocialConnection]? {
        do {
            let oauths = try await fetchMyOAuthUseCase.execute()
            let connections = oauths.compactMap(SocialConnection.init(memberOAuth:))
            SocialType.saveConnected(connections.map(\.socialType))
            return connections
        } catch {
            return nil
        }
    }

    /// 소셜 타입별 OAuth 로그인을 수행하여 검증 토큰을 반환합니다.
    @MainActor
    private func fetchOAuthVerificationToken(social: SocialType) async throws -> String {
        let result: OAuthLoginResult

        switch social {
        case .kakao:
            let (accessToken, email) = try await kakaoLoginManager.login()
            result = try await loginUseCase.executeKakao(accessToken: accessToken, email: email)
        case .apple:
            let authorizationCode = try await fetchAppleAuthorizationCode()
            result = try await loginUseCase.executeApple(
                authorizationCode: authorizationCode,
                email: nil,
                fullName: nil
            )
        case .google:
            let accessToken = try await googleLoginManager.fetchAccessToken()
            result = try await loginUseCase.executeGoogle(accessToken: accessToken)
        }

        return try extractVerificationToken(from: result, providerName: social.rawValue)
    }

    /// `AppleLoginManager`의 콜백을 async/await로 브릿징하여 authorization code를 반환합니다.
    @MainActor
    private func fetchAppleAuthorizationCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            appleLoginManager.onAuthorizationCompleted = { code, _, _ in
                continuation.resume(returning: code)
            }
            appleLoginManager.onAuthorizationFailed = { error in
                continuation.resume(throwing: error)
            }
            appleLoginManager.signWithApple()
        }
    }

    /// `OAuthLoginResult`에서 연동용 검증 토큰을 추출합니다.
    ///
    /// - Note: 검증 토큰은 신규 회원(`newMember`) 응답에만 존재합니다. 기존 회원은 이미 다른
    ///   계정에 연결된 소셜이므로 연동 불가로 에러를 던집니다.
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
}
