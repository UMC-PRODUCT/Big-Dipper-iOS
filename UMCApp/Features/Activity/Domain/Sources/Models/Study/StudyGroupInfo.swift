//
//  StudyGroupInfo.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import UMCFoundation

/// 스터디 그룹 정보 모델
///
/// 스터디 그룹의 기본 정보, 담당 파트장 목록, 스터디원 목록을 포함합니다.
public struct StudyGroupInfo: Identifiable, Equatable {

    // MARK: - Property

    public let id: UUID
    public let serverID: String
    public let name: String
    public let part: UMCPartType
    public let createdDate: Date
    public var mentors: [StudyGroupMember]
    public var members: [StudyGroupMember]

    // MARK: - Computed Property

    /// 전체 챌린저 수 (파트장 포함)
    public var memberCount: Int { members.count + mentors.count }

    /// 스터디장
    public var primaryMentor: StudyGroupMember? { mentors.first }

    /// 생성일 포맷 문자열 (yyyy.MM.dd, KST 기준)
    public var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: createdDate)
    }

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        serverID: String,
        name: String,
        part: UMCPartType,
        createdDate: Date,
        mentors: [StudyGroupMember],
        members: [StudyGroupMember] = []
    ) {
        self.id = id
        self.serverID = serverID
        self.name = name
        self.part = part
        self.createdDate = createdDate
        self.mentors = mentors
        self.members = members
    }
}
