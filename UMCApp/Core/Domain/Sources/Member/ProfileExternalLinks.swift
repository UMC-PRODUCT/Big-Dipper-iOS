/// 외부 프로필 링크 (MyPage `MyPageProfileExternalLinksDTO`의 도메인 대응).
public struct ProfileExternalLinks: Equatable, Hashable, Sendable {

    // MARK: - Property

    public let id: String
    public let linkedIn: String?
    public let instagram: String?
    public let github: String?
    public let blog: String?
    public let personal: String?

    // MARK: - Init

    public init(
        id: String,
        linkedIn: String?,
        instagram: String?,
        github: String?,
        blog: String?,
        personal: String?
    ) {
        self.id = id
        self.linkedIn = linkedIn
        self.instagram = instagram
        self.github = github
        self.blog = blog
        self.personal = personal
    }
}
