import Foundation
import UMCFoundation

/// 앱 전역에서 공유하는 현재 로그인 사용자의 최고 권한 역할 상태.
///
/// `SyncProfileStorageUseCase`가 프로필 동기화 시점에 갱신하며, Notice 등 권한 분기가
/// 필요한 화면에서 관찰한다.
@Observable
public final class UserSessionManager {

    // MARK: - Property

    public private(set) var currentRole: ManagementTeam = .challenger

    // MARK: - Init

    public init() {}

    // MARK: - Function

    public func updateRole(_ role: ManagementTeam) {
        currentRole = role
    }
}
