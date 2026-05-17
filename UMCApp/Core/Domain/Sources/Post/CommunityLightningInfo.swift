//
//  CommunityLightningInfo.swift
//  CoreDomain
//
//  Created by 김미주 on 5/10/26.
//

import Foundation

/// 번개(Lightning) 모임 정보
public struct CommunityLightningInfo: Equatable, Hashable {
    public let meetAt: Date
    public let location: String
    public let maxParticipants: Int
    public let openChatUrl: String

    public init(
        meetAt: Date,
        location: String,
        maxParticipants: Int,
        openChatUrl: String
    ) {
        self.meetAt = meetAt
        self.location = location
        self.maxParticipants = maxParticipants
        self.openChatUrl = openChatUrl
    }
}
