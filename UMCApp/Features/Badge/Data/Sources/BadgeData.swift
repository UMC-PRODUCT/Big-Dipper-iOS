import BadgeDomain

public struct BadgeRepository: FetchBadgesUseCaseProtocol {
    public init() {}

    public func execute() async throws -> [Badge] {
        []
    }
}
