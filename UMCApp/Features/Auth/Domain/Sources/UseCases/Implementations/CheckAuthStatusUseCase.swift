/// 앱 부트스트랩 시점의 인증 상태 판정 UseCase 구현체
///
/// 토큰 존재 → 세션 강제 갱신 → 프로필 조회 → 승인 판정 순으로 진행한다.
/// 세션 강제 갱신이 실패해도 기존 액세스 토큰으로 프로필 조회를 한 번 더 시도한다
/// (레거시 `AuthBootstrapViewModel.resolveAuthStatus()`와 동일한 완화 정책).
public final class CheckAuthStatusUseCase: CheckAuthStatusUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol

    // MARK: - Init

    public init(
        repository: AuthRepositoryProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    ) {
        self.repository = repository
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
    }

    // MARK: - Function

    public func execute() async -> AuthBootstrapStatus {
        guard await repository.hasSession() else {
            return .notLoggedIn
        }

        do {
            try await repository.refreshSession()
        } catch {
            // 갱신 실패 시에도 기존 액세스 토큰으로 프로필 조회를 시도한다.
        }

        do {
            let profile = try await fetchMyProfileUseCase.execute()
            return profile.isApproved ? .approved : .pendingApproval
        } catch {
            // TODO: [후속 하드닝] 프로필 조회 최종 실패 시 Keychain 토큰 정리 필요 — 레거시
            // AuthBootstrapViewModel.resolveAuthStatus()의 networkClient.logout() 대응.
            // 일시적 네트워크 오류와 영구 무효(401/403) 구분 정책 포함.
            return .notLoggedIn
        }
    }
}
