//
//  BadgeData.swift
//  BadgeData
//
//  Created by euijjang97 on 4/23/26.
//

import BadgeDomain

public struct BadgeRepository: FetchBadgesUseCaseProtocol {
    public init() {}

    public func execute() async throws -> [Badge] {
        []
    }
}
