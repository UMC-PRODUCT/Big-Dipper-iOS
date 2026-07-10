import UMCFoundation

/// 멤버가 보유한 기수별 역할 정보.
///
/// Auth `ProfileRole`(4필드)과 MyPage `MyPageRoleDTO`의 `id`/`challengerId`/`gisuId`/
/// `responsiblePart`를 병합한 정본 모델이다.
public struct ProfileRole: Equatable, Hashable, Sendable {

    // MARK: - Property

    /// 역할 레코드의 서버 식별자 (MyPage 병합 필드)
    public let id: String
    /// 역할이 속한 챌린저 기록 ID (MyPage 병합 필드)
    public let challengerId: String
    public let gisu: String
    /// 서버 기수 식별 ID (MyPage 병합 필드)
    public let gisuId: String
    public let roleType: ManagementTeam
    public let organizationType: OrganizationType
    public let organizationId: String?
    /// 담당 파트 (MyPage 병합 필드)
    public let responsiblePart: String?

    // MARK: - Init

    public init(
        id: String = "",
        challengerId: String = "",
        gisu: String,
        gisuId: String = "",
        roleType: ManagementTeam,
        organizationType: OrganizationType,
        organizationId: String?,
        responsiblePart: String? = nil
    ) {
        self.id = id
        self.challengerId = challengerId
        self.gisu = gisu
        self.gisuId = gisuId
        self.roleType = roleType
        self.organizationType = organizationType
        self.organizationId = organizationId
        self.responsiblePart = responsiblePart
    }
}
