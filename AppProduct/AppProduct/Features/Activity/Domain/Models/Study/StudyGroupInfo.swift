//
//  StudyGroupInfo.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

/// 스터디 그룹 정보 모델
///
/// 스터디 그룹의 기본 정보, 파트장, 스터디원 목록을 포함합니다.
struct StudyGroupInfo: Identifiable, Equatable {

    // MARK: - Property

    /// 고유 식별자
    let id: UUID

    /// 서버 식별자
    let serverID: String

    /// 그룹명
    let name: String

    /// 파트 타입
    let part: UMCPartType

    /// 생성일
    let createdDate: Date

    /// 담당 파트장
    let leader: StudyGroupMember

    /// 스터디원 목록 (파트장 제외)
    var members: [StudyGroupMember]

    // MARK: - Computed Property

    /// 전체 멤버 수 (파트장 포함)
    var memberCount: Int { members.count + 1 }

    /// 생성일 포맷 문자열
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: createdDate)
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        serverID: String,
        name: String,
        part: UMCPartType,
        createdDate: Date,
        leader: StudyGroupMember,
        members: [StudyGroupMember] = []
    ) {
        self.id = id
        self.serverID = serverID
        self.name = name
        self.part = part
        self.createdDate = createdDate
        self.leader = leader
        self.members = members
    }
}

// MARK: - Preview Data

extension StudyGroupInfo {
    static let preview = StudyGroupInfo(
        serverID: "group_001",
        name: "React A팀",
        part: .front(type: .web),
        createdDate: {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.date(from: "2024.03.01") ?? Date()
        }(),
        leader: StudyGroupMember(
            serverID: "member_001",
            name: "홍길동",
            nickname: "길동이",
            university: "중앙대",
            role: .leader
        ),
        members: [
            StudyGroupMember(
                serverID: "member_002",
                name: "홍길동",
                nickname: "길동2",
                university: "서울대",
                bestWorkbookPoint: 30
            ),
            StudyGroupMember(
                serverID: "member_003",
                name: "홍길동",
                nickname: "길동3",
                university: "한양대"
            ),
            StudyGroupMember(
                serverID: "member_004",
                name: "홍길동",
                university: "연세대"
            ),
        ]
    )
}
