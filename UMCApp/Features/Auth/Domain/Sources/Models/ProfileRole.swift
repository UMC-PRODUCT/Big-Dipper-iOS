import UMCFoundation

/// 멤버가 보유한 기수별 역할 정보.
public struct ProfileRole: Equatable, Sendable {

    // MARK: - Property

    public let gisu: String
    public let roleType: ManagementTeam
    public let organizationType: OrganizationType
    public let organizationId: String?

    // MARK: - Init

    public init(
        gisu: String,
        roleType: ManagementTeam,
        organizationType: OrganizationType,
        organizationId: String?
    ) {
        self.gisu = gisu
        self.roleType = roleType
        self.organizationType = organizationType
        self.organizationId = organizationId
    }
}
