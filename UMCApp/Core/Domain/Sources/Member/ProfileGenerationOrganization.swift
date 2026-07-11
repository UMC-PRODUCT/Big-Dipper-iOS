/// 기수별 소속 조직(지부/학교) 정보.
///
/// `SyncProfileStorageUseCase`가 UserDefaults에 JSON 문자열로 저장하기 위해
/// `Codable`을 채택한다. `Hashable`은 정본 `Profile` 애그리게이트가 `Hashable`을 요구하기 때문에
/// 함께 채택한다.
public struct ProfileGenerationOrganization: Equatable, Hashable, Sendable, Codable {

    // MARK: - Property

    public let gen: String
    public let chapterId: String?
    public let chapterName: String?
    public let schoolId: String?
    public let schoolName: String?

    // MARK: - Init

    public init(
        gen: String,
        chapterId: String?,
        chapterName: String?,
        schoolId: String?,
        schoolName: String?
    ) {
        self.gen = gen
        self.chapterId = chapterId
        self.chapterName = chapterName
        self.schoolId = schoolId
        self.schoolName = schoolName
    }
}
