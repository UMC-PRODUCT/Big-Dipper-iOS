//
//  StudyGroupPreviewData.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/11/26.
//

import Foundation
import SwiftData

struct StudyGroupPreviewData {
    static let container: DIContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try! ModelContainer(
            for: GenerationMappingRecord.self, NoticeHistoryData.self,
            configurations: config
        )
        return DIContainer.configured(
            modelContext: modelContainer.mainContext
        )
    }()
    static let errorHandler = ErrorHandler()

    // MARK: - Mock Groups

    static let groups: [StudyGroupInfo] = [
        // 1. React A — Web
        StudyGroupInfo(
            serverID: "group_001",
            name: "React A",
            part: .front(type: .web),
            createdDate: date("2024.03.01"),
            leader: StudyGroupMember(
                serverID: "m_001",
                name: "김연진",
                nickname: "코튼",
                university: "상명대",
                role: .leader
            ),
            members: [
                StudyGroupMember(
                    serverID: "m_002",
                    name: "이수빈",
                    nickname: "수비",
                    university: "국민대",
                    bestWorkbookPoint: 20
                ),
                StudyGroupMember(
                    serverID: "m_003",
                    name: "박지호",
                    university: "동국대"
                ),
            ]
        ),
        // 2. Spring 스터디 — Spring
        StudyGroupInfo(
            serverID: "group_002",
            name: "Spring 스터디",
            part: .server(type: .spring),
            createdDate: date("2024.03.05"),
            leader: StudyGroupMember(
                serverID: "m_010",
                name: "박경운",
                nickname: "하늘",
                university: "중앙대",
                role: .leader
            ),
            members: [
                StudyGroupMember(
                    serverID: "m_011",
                    name: "조민재",
                    university: "아주대"
                ),
            ]
        ),
        // 3. iOS Deep Dive — iOS
        StudyGroupInfo(
            serverID: "group_003",
            name: "iOS Deep Dive",
            part: .front(type: .ios),
            createdDate: date("2024.03.10"),
            leader: StudyGroupMember(
                serverID: "m_020",
                name: "이재원",
                nickname: "리버",
                university: "한성대",
                role: .leader
            ),
            members: [
                StudyGroupMember(
                    serverID: "m_021",
                    name: "이예지",
                    nickname: "소피",
                    university: "가천대",
                    bestWorkbookPoint: 35
                ),
                StudyGroupMember(
                    serverID: "m_022",
                    name: "김미주",
                    nickname: "마티",
                    university: "덕성여대"
                ),
            ]
        ),
        // 4. Android Compose — Android
        StudyGroupInfo(
            serverID: "group_004",
            name: "Android Compose",
            part: .front(type: .android),
            createdDate: date("2024.03.12"),
            leader: StudyGroupMember(
                serverID: "m_030",
                name: "박유수",
                nickname: "어헛차",
                university: "숭실대",
                role: .leader
            ),
            members: [
                StudyGroupMember(
                    serverID: "m_031",
                    name: "김태현",
                    university: "세종대",
                    bestWorkbookPoint: 10
                ),
            ]
        ),
        // 5. UX 리서치 — Design
        StudyGroupInfo(
            serverID: "group_005",
            name: "UX 리서치",
            part: .design,
            createdDate: date("2024.03.15"),
            leader: StudyGroupMember(
                serverID: "m_040",
                name: "이희원",
                nickname: "삼이",
                university: "성신여대",
                role: .leader
            ),
            members: [
                StudyGroupMember(
                    serverID: "m_041",
                    name: "윤서연",
                    university: "홍익대"
                ),
            ]
        ),
        // 6. PM 전략 — PM
        StudyGroupInfo(
            serverID: "group_006",
            name: "PM 전략",
            part: .pm,
            createdDate: date("2024.03.18"),
            leader: StudyGroupMember(
                serverID: "m_050",
                name: "정의찬",
                nickname: "제옹",
                university: "중앙대",
                role: .leader
            )
        ),
        // 7. Node Express — Node
        StudyGroupInfo(
            serverID: "group_007",
            name: "Node Express",
            part: .server(type: .node),
            createdDate: date("2024.03.20"),
            leader: StudyGroupMember(
                serverID: "m_060",
                name: "정성훈",
                nickname: "노디",
                university: "경희대",
                role: .leader
            ),
            members: [
                StudyGroupMember(
                    serverID: "m_061",
                    name: "오지은",
                    university: "중앙대"
                ),
            ]
        ),
    ]

    // MARK: - Helper

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.date(from: string) ?? Date()
    }
}
