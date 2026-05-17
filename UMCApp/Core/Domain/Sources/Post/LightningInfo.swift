//
//  LightningInfo.swift
//  CoreDomain
//
//  번개 모임(Lightning) 공통 정보 도메인 모델.
//  Community/MyPage 등 여러 Feature에서 동일하게 사용되므로 Core/Domain에 위치한다.
//

import Foundation

public struct LightningInfo: Equatable, Hashable {
    public let meetAt: Date
    public let location: String
    public let maxParticipants: String
    public let openChatUrl: String

    public init(
        meetAt: Date,
        location: String,
        maxParticipants: String,
        openChatUrl: String
    ) {
        self.meetAt = meetAt
        self.location = location
        self.maxParticipants = maxParticipants
        self.openChatUrl = openChatUrl
    }
}
