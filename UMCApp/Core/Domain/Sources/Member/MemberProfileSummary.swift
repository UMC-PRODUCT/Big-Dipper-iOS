//
//  MemberProfileSummary.swift
//  CoreDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 특정 멤버 프로필 조회 응답에서 작성자 표시용으로 추출할 정보
public struct MemberProfileSummary: Equatable, Hashable {
    public let memberId: String
    public let name: String
    public let nickname: String
    public let generation: Int
    public let organizationName: String?
    public let roleName: String
    public let profileImageURL: String?

    public init(
        memberId: String,
        name: String,
        nickname: String,
        generation: Int,
        organizationName: String?,
        roleName: String,
        profileImageURL: String?
    ) {
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.generation = generation
        self.organizationName = organizationName
        self.roleName = roleName
        self.profileImageURL = profileImageURL
    }
}
