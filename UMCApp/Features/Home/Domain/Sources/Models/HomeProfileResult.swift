/// 홈 화면 시즌/세대 카드 구성에 필요한 프로필 조회 결과.
public struct HomeProfileResult: Equatable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let seasonTypes: [SeasonType]
    public let generations: [HomeGeneration]

    // MARK: - Init

    public init(memberId: String, seasonTypes: [SeasonType], generations: [HomeGeneration]) {
        self.memberId = memberId
        self.seasonTypes = seasonTypes
        self.generations = generations
    }
}
