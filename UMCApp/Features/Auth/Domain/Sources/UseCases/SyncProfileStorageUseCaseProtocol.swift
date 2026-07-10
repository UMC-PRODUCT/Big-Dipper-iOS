import CoreDomain

/// 프로필 조회 결과를 로컬 저장소(`UserDefaults`, `UserSessionManager`)에 동기화하는 UseCase 인터페이스
public protocol SyncProfileStorageUseCaseProtocol {
    /// 프로필 정보를 `AppStorageKey` 기반 `UserDefaults`와 `UserSessionManager`에 반영한다.
    /// - Parameter profile: 동기화할 프로필 정보
    func execute(profile: Profile)
}
