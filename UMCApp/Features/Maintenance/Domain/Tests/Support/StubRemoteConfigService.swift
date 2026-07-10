@testable import MaintenanceDomain

/// `RemoteConfigServiceProtocol`의 테스트용 Stub 구현체
///
/// 실제 Firebase 접근 없이 고정된 값을 반환한다.
final class StubRemoteConfigService: RemoteConfigServiceProtocol, @unchecked Sendable {

    var stubbedMaintenanceInfo: MaintenanceInfo?
    var stubbedMinimumVersion: String?

    init(
        stubbedMaintenanceInfo: MaintenanceInfo? = nil,
        stubbedMinimumVersion: String? = nil
    ) {
        self.stubbedMaintenanceInfo = stubbedMaintenanceInfo
        self.stubbedMinimumVersion = stubbedMinimumVersion
    }

    func fetchMaintenanceStatus() async -> MaintenanceInfo? {
        stubbedMaintenanceInfo
    }

    func fetchMinimumSupportedVersion() async -> String? {
        stubbedMinimumVersion
    }
}
