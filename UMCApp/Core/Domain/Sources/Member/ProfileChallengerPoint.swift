//
//  ProfileChallengerPoint.swift
//  CoreDomain
//
//  Created by euijjang97 on 7/11/26.
//

/// 챌린저 기록의 포인트(가점/감점) 이력 한 건.
public struct ProfileChallengerPoint: Equatable, Hashable, Sendable {

    // MARK: - Property

    public let id: String
    public let pointType: String
    public let point: Double
    public let description: String
    public let createdAt: String

    // MARK: - Init

    public init(
        id: String,
        pointType: String,
        point: Double,
        description: String,
        createdAt: String
    ) {
        self.id = id
        self.pointType = pointType
        self.point = point
        self.description = description
        self.createdAt = createdAt
    }
}
