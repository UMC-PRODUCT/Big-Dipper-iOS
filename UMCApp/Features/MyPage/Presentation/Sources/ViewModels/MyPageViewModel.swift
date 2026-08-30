//
//  MyPageViewModel.swift
//  MyPagePresentation
//
//  Created by One on 5/24/26.
//

import AuthDomain
import BusinessCardDomain
import BusinessCardPresentation
import CommunityDomain
import CoreDI
import CoreDomain
import CoreGraphics
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

    /// 명함 편집 진입이 아직 준비되지 않았다.
    ///
    /// `myCard`는 프로필 응답이 도착하는 즉시 `.loaded`가 되지만, `profileData`는 이어지는
    /// `/member-oauth/me` 왕복(``syncConnectedSocials``)까지 끝나야 `.loaded`가 된다 —
    /// 그래서 처음 진입에 "명함 카드는 떠 있는데 편집 스냅샷은 아직"인 구간이 생긴다. 이
    /// 구간에는 명함 편집 행을 비활성화해 조용히 씹히는 탭을 막는다(뷰가 소비).
    /// pop 복귀 재조회는 로드된 프로필을 유지하므로(``fetchProfile``) 다시 켜지지 않는다.
    public var isCardEditPending: Bool {
        switch profileData {
        case .idle, .loading: return true
        case .loaded, .failed: return false
        }
    }

    /// 내 명함(v3 루트 카드). BusinessCardDomain이 정본 프로필 파이프라인에서 파생시킨다.
    public private(set) var myCard: Loadable<MyCard> = .idle

    /// 카드 실패 화면의 재시도가 진행 중이다.
    ///
    /// retry(`MyPageView.retryCardAndProfile`)는 프로필 재조회를 먼저 기다린 뒤 카드를
    /// 다시 읽는다 — 그 앞 구간에는 `myCard`가 여전히 `.failed`라 `myCard.isLoading`만
    /// 보면 스피너가 늦게 돈다(버튼이 씹힌 것처럼 보인다). 두 로드 중 어느 쪽이 돌아도
    /// 재시도 중으로 본다. `.failed` 분기의 재시도 UI만 소비한다.
    public var isCardRetryInFlight: Bool {
        myCard.isLoading || profileData.isLoading
    }

    /// v3 루트 행 우측 카운트(받은 명함·스터디·활동·북마크). 조회 실패 소스는 "0"으로
    /// 채워져 오므로(``ActivityStat/empty``) 별도 실패 상태를 두지 않는다.
    public private(set) var activityStat: ActivityStat = .empty

    /// 명함 카드 뒷면 QR. 카드 로드에 성공해도 생성이 실패하면 `nil`로 남는다
    /// (``CardQRViewModel``과 같은 정책 — QR만 못 만들었다고 카드까지 감출 이유가 없다).
    public private(set) var qrImage: CGImage?

    /// Alert 표시를 위한 프롬프트 상태 (확인/취소 다이얼로그).
    public var alertPrompt: AlertPrompt?

    /// `loadBusinessCard` 중복 호출 가드. 로드된 카드를 유지한 채 재조회하는 동안에는
    /// `myCard`가 `.loading`이 아니라서 상태만으로는 인플라이트를 알 수 없다.
    private var isCardLoadInFlight = false

    /// `fetchProfile` 중복 호출 가드. 위와 같은 이유 — 로드된 프로필을 유지한 채
    /// 재조회하는 동안 `profileData`는 `.loading`이 아니다.
    private var isProfileLoadInFlight = false

    private let container: DIContainer
    private let myPageProvider: MyPageUseCaseProviding
    private let businessCardProvider: BusinessCardUseCaseProviding
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
        self.businessCardProvider = container.resolve(BusinessCardUseCaseProviding.self)
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
    /// 이미 로드된 프로필이 있으면 그대로 둔 채 재조회합니다(stale-while-revalidate,
    /// ``loadBusinessCard``와 같은 정책) — pop 복귀 재조회마다 `.loading`으로 밀면
    /// ``isCardEditPending``이 다시 켜져 「명함 편집」·「나의 활동 ・프로젝트」 행이 함께
    /// 스피너를 돌린다. 처음 진입·실패 후 재시도만 로딩 상태를 그립니다.
    ///
    /// 이미 조회가 진행 중이면 중복 호출을 무시합니다. 에러 분기:
    /// - `CancellationError` / `NSURLErrorCancelled` → 이전 상태 복원
    /// - `AppError` → `.failed(error)`
    /// - 그 외 → `.failed(.unknown(message:))`
    ///
    /// - Parameter forceRefresh: `true`이면 세션 프로필 캐시를 우회해 서버 최신으로 갱신한다.
    @MainActor
    public func fetchProfile(forceRefresh: Bool = false) async {
        if isProfileLoadInFlight { return }
        isProfileLoadInFlight = true
        defer { isProfileLoadInFlight = false }

        let previousState = profileData
        if profileData.value == nil {
            profileData = .loading
        }

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

    /// 내 명함과 v3 루트 행 카운트, 카드 뒷면 QR을 조회합니다.
    ///
    /// `fetchProfile`과 별개 상태·별개 UseCase다 — 명함은 같은 정본 프로필 캐시에서 파생되지만
    /// (``BusinessCardUseCaseProviding``), 화면이 그 캐시를 두 번 조회한다고 왕복이 늘지는 않는다.
    /// 에러 분기는 `fetchProfile`과 동일한 규칙을 따른다.
    ///
    /// 이미 로드된 카드가 있으면 그대로 보여 둔 채 재조회한다(stale-while-revalidate) —
    /// pop 복귀 재조회마다 `.loading`으로 밀면 카드 전체가 깜빡이고, 재조회가 취소되면
    /// `qrImage`가 빈 채 남는다. 그래서 중복 호출 가드도 상태(`.loading`)가 아니라
    /// 별도 플래그로 건다. 처음 진입·실패 후 재시도만 로딩 상태를 그린다.
    ///
    /// - Parameter forceRefresh: `true`이면 프로필 캐시를 우회해 서버 최신으로 갱신한다.
    @MainActor
    public func loadBusinessCard(forceRefresh: Bool = false) async {
        if isCardLoadInFlight { return }
        isCardLoadInFlight = true
        defer { isCardLoadInFlight = false }

        let previousState = myCard
        if myCard.value == nil {
            myCard = .loading
            qrImage = nil
        }

        activityStat = await businessCardProvider.fetchActivityStatUseCase.execute()

        do {
            let card = try await businessCardProvider.fetchMyCardUseCase.execute(
                forceRefresh: forceRefresh
            )
            myCard = .loaded(card)
            // QR만 못 만들었다고 카드까지 감출 이유가 없다. 카드는 그대로 두고
            // QR 자리만 비운다 — 화면이 그 상태를 플레이스홀더로 그린다.
            qrImage = try? businessCardProvider.generateCardQRUseCase.execute(for: card)
        } catch is CancellationError {
            myCard = previousState
        } catch let error as AppError {
            myCard = Self.failureState(error, previous: previousState)
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            myCard = previousState
        } catch {
            myCard = Self.failureState(
                .unknown(message: error.localizedDescription),
                previous: previousState
            )
        }
    }

    /// 재조회 실패를 어떤 상태로 실을지 정한다.
    ///
    /// 보여줄 카드가 이미 있으면 실패로 덮지 않는다 — 실패한 건 **갱신**이지 카드가 아니다.
    /// 화면 전체를 재시도 뷰로 바꾸면 pop 복귀 재조회 중 네트워크가 한 번 흔들린 것만으로
    /// 멀쩡히 보이던 카드가 사라진다. 오래된 값을 그대로 두는 쪽이 stale-while-revalidate의
    /// 나머지 반쪽이다(취소 경로만 보존하면 계약이 절반만 성립한다).
    ///
    /// - Note: 그 대가로 **갱신 실패가 조용해진다.** 카드가 낡은 채 남고 화면에 실패 표시가
    ///   없다. 다음 진입·pop 복귀가 다시 조회하므로 스스로 회복하며, 보여줄 카드가 아예
    ///   없을 때(처음 진입·실패 후 재시도)는 그대로 `.failed`로 전이해 사용자가 재시도할 수 있다.
    static func failureState(
        _ error: AppError,
        previous: Loadable<MyCard>
    ) -> Loadable<MyCard> {
        previous.value == nil ? .failed(error) : previous
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
    ///
    /// 명함첩은 서버 사본이 없는 로컬(+CloudKit) 데이터라 계정을 지워도 기기에 남는다.
    /// 세션 정리보다 **먼저** 비우는 이유는 저장소가 현재 로그인 계정으로 스코프되기
    /// 때문이다 — `tearDownSession()`이 세션 키를 지운 뒤에는 지울 대상을 특정할 수 없다.
    /// 로그아웃에는 이 정리를 붙이지 않는다(다시 로그인하면 돌아와야 하는 데이터다).
    @MainActor
    public func deleteAccount() async throws {
        try await myPageProvider.deleteMemberUseCase.execute()
        try await businessCardProvider.deleteReceivedCardUseCase.executeAll()
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
