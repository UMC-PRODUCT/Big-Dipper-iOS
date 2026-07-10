/// 원격 킬스위치(RemoteConfig) 기반 점검 상태 정보.
public struct MaintenanceInfo: Equatable, Sendable {

    // MARK: - Property

    public let isActive: Bool
    public let title: String
    public let message: String

    // MARK: - Init

    public init(isActive: Bool, title: String, message: String) {
        self.isActive = isActive
        self.title = title
        self.message = message
    }
}
