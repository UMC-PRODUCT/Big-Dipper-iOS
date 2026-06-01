//
//  StudyGroupMember.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 스터디 그룹 내 챌린저 모델
///
/// 스터디 그룹의 리더/챌린저 정보를 표현합니다.
public struct StudyGroupMember: Identifiable, Equatable, Hashable {

    // MARK: - Nested Types

    /// 챌린저 역할
    public enum MemberRole: String, Equatable, Hashable {
        case leader = "Leader"
        case member = "Member"
    }

    // MARK: - Property

    public let id: UUID
    public let serverID: String
    public let challengerID: String?
    public let memberID: String?
    public let name: String
    public let nickname: String?
    public let university: String
    public let profileImageURL: String?
    public let role: MemberRole
    public let bestWorkbookPoint: Int

    // MARK: - Computed Property

    /// 표시용 이름 — 닉네임이 있으면 "닉네임/이름", 없으면 "이름"
    public var displayName: String {
        if let nickname { return "\(nickname)/\(name)" }
        return name
    }

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        serverID: String,
        challengerID: String? = nil,
        memberID: String? = nil,
        name: String,
        nickname: String? = nil,
        university: String,
        profileImageURL: String? = nil,
        role: MemberRole = .member,
        bestWorkbookPoint: Int = 0
    ) {
        self.id = id
        self.serverID = serverID
        self.challengerID = challengerID
        self.memberID = memberID
        self.name = name
        self.nickname = nickname
        self.university = university
        self.profileImageURL = profileImageURL
        self.role = role
        self.bestWorkbookPoint = bestWorkbookPoint
    }
}
