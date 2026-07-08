/// 부트스트랩 승인 판정에 필요한 최소 프로필 정보.
///
/// 서버 정수 필드(멤버 ID, 기수 번호)는 절대규칙 #2에 따라 전 레이어 `String`으로 유지한다.
public struct Profile: Equatable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let name: String
    public let nickname: String
    /// 소속 기수 번호 목록 (역할/챌린저 기록에서 파생)
    public let generations: [String]

    // MARK: - Init

    public init(memberId: String, name: String, nickname: String, generations: [String]) {
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.generations = generations
    }

    // MARK: - Function

    /// 소속 기수가 하나라도 있으면 승인된 챌린저로 판단한다.
    public var isApproved: Bool {
        !generations.isEmpty
    }
}
