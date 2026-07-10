import UMCFoundation

/// Auth/Home/MyPage가 공유하는 정본 프로필 애그리게이트.
///
/// 서버 정수 필드(멤버/학교/지부 ID, 기수 번호)는 절대규칙 #2에 따라 전 레이어 `String`으로 유지한다.
/// 필드 구성은 Auth(부트스트랩 승인 판정), Home(`seasonTypes`/`generations` 파생), MyPage(프로필 화면
/// 전체 항목 + 챌린저 기록)가 각각 필요로 하는 항목의 합집합이다.
public struct Profile: Equatable, Hashable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let name: String
    public let nickname: String
    /// 소속 기수 번호 목록 (역할/챌린저 기록에서 파생)
    public let generations: [String]
    public let schoolId: String
    public let schoolName: String
    /// 최신 기수 챌린저 기록 ID (`challengerRecords`가 비어 있으면 `nil`)
    public let latestChallengerId: String?
    /// 최신 기수의 서버 기수 식별 ID
    public let latestGisuId: String?
    /// 최신 기수 지부 ID
    public let chapterId: String?
    /// 최신 기수 지부 이름
    public let chapterName: String
    /// 최신 기수 담당 파트 (서버 API 문자열, 예: "IOS")
    public let responsiblePart: String?
    /// 보유 역할 목록
    public let roles: [ProfileRole]
    /// 기수별 소속 조직 정보
    public let generationOrganizations: [ProfileGenerationOrganization]
    /// 계정 이메일 (MyPage 병합 필드)
    public let email: String
    /// 프로필 이미지 URL (MyPage 병합 필드)
    public let profileImageLink: String?
    /// 멤버 활동 상태 (MyPage 병합 필드)
    public let status: MemberStatus
    /// 외부 프로필 링크 (MyPage 병합 필드)
    public let externalLinks: ProfileExternalLinks?
    /// 기수별 챌린저 활동 기록 (MyPage 병합 필드)
    public let challengerRecords: [ProfileChallengerRecord]

    // MARK: - Init

    public init(
        memberId: String,
        name: String,
        nickname: String,
        generations: [String],
        schoolId: String = "",
        schoolName: String = "",
        latestChallengerId: String? = nil,
        latestGisuId: String? = nil,
        chapterId: String? = nil,
        chapterName: String = "",
        responsiblePart: String? = nil,
        roles: [ProfileRole] = [],
        generationOrganizations: [ProfileGenerationOrganization] = [],
        email: String = "",
        profileImageLink: String? = nil,
        status: MemberStatus = .active,
        externalLinks: ProfileExternalLinks? = nil,
        challengerRecords: [ProfileChallengerRecord] = []
    ) {
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.generations = generations
        self.schoolId = schoolId
        self.schoolName = schoolName
        self.latestChallengerId = latestChallengerId
        self.latestGisuId = latestGisuId
        self.chapterId = chapterId
        self.chapterName = chapterName
        self.responsiblePart = responsiblePart
        self.roles = roles
        self.generationOrganizations = generationOrganizations
        self.email = email
        self.profileImageLink = profileImageLink
        self.status = status
        self.externalLinks = externalLinks
        self.challengerRecords = challengerRecords
    }

    // MARK: - Function

    /// 소속 기수가 하나라도 있으면 승인된 챌린저로 판단한다.
    public var isApproved: Bool {
        !generations.isEmpty
    }
}
