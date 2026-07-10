import CoreDomain
@testable import AuthDomain

/// `SyncProfileStorageUseCaseProtocol`의 테스트용 Spy 구현체
///
/// 실제 저장 동작 없이 호출 여부/전달받은 프로필만 기록합니다.
final class SyncProfileStorageSpy: SyncProfileStorageUseCaseProtocol, @unchecked Sendable {
    private(set) var executeCallCount = 0
    private(set) var receivedProfile: Profile?

    func execute(profile: Profile) {
        executeCallCount += 1
        receivedProfile = profile
    }
}
