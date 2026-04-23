import Foundation

public struct Badge: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let category: BadgeCategory
    public let imageName: String

    public init(
        id: String,
        name: String,
        description: String,
        category: BadgeCategory,
        imageName: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.imageName = imageName
    }
}

public enum BadgeCategory: String, Equatable, CaseIterable {
    case attendance
    case notice
    case community
    case activity
    case special
}

public struct BadgeProgress: Equatable {
    public let badgeId: String
    public let current: Int
    public let target: Int
    public let isUnlocked: Bool

    public init(badgeId: String, current: Int, target: Int, isUnlocked: Bool) {
        self.badgeId = badgeId
        self.current = current
        self.target = target
        self.isUnlocked = isUnlocked
    }
}

public struct BadgeUnlockEvent: Equatable {
    public let badgeId: String
    public let unlockedAt: Date

    public init(badgeId: String, unlockedAt: Date) {
        self.badgeId = badgeId
        self.unlockedAt = unlockedAt
    }
}

public protocol FetchBadgesUseCaseProtocol {
    func execute() async throws -> [Badge]
}
