//
//  MyPageMockData.swift
//  AppProduct
//
//  Created by euijjang97 on 2/15/26.
//

import Foundation

enum MyPageMockData {
    static let profile = ProfileData(
        challengeId: 269,
        challangerInfo: ChallengerInfo(
            memberId: 1001,
            gen: 8,
            name: "홍길동",
            nickname: "길동",
            schoolName: "한성대학교",
            profileImage: nil,
            part: .front(type: .ios)
        ),
        socialConnections: [
            .init(memberOAuthId: 1, socialType: .kakao),
            .init(memberOAuthId: 2, socialType: .apple)
        ],
        activityLogs: [
            .init(
                part: .front(type: .ios),
                generation: 8,
                role: .challenger
            ),
            .init(
                part: .server(type: .spring),
                generation: 7,
                role: .schoolPartLeader
            ),
            .init(
                part: .design,
                generation: 6,
                role: .schoolPresident
            )
        ],
        profileLink: [
            .init(type: .github, url: "https://github.com/euijjang97"),
            .init(type: .linkedin, url: "https://linkedin.com/in/euijjang97"),
            .init(type: .blog, url: "https://velog.io/@euijjang97")
        ]
    )

    static let posts: [CommunityItemModel] = [
        .init(
            postId: 1,
            userId: 1001,
            category: .free,
            title: "스터디원 모집합니다",
            content: "Spring Boot 스터디원 모집합니다.",
            profileImage: nil,
            userName: "홍길동",
            userNickname: "길동이",
            part: .front(type: .ios),
            createdAt: Date(),
            likeCount: 42,
            commentCount: 5,
            scrapCount: 0,
            isLiked: true,
            isAuthor: true,
            lightningInfo: nil
        ),
        .init(
            postId: 1,
            userId: 1001,
            category: .question,
            title: "SwiftUI 네비게이션 질문",
            content: "NavigationStack 경로 분리 패턴을 어떻게 관리하시나요?",
            profileImage: nil,
            userName: "홍길동",
            userNickname: "길동이",
            part: .front(type: .ios),
            createdAt: Date(),
            likeCount: 13,
            commentCount: 4,
            scrapCount: 0,
            isLiked: false,
            isAuthor: true,
            lightningInfo: nil
        ),
        .init(
            postId: 1,
            userId: 1001,
            category: .lighting,
            title: "번개: 강남역 커피챗",
            content: "iOS 아키텍처 얘기하실 분 모집합니다.",
            profileImage: nil,
            userName: "홍길동",
            userNickname: "길동이",
            part: .front(type: .ios),
            createdAt: Date(),
            likeCount: 7,
            commentCount: 1,
            scrapCount: 0,
            isLiked: true,
            isAuthor: true,
            lightningInfo: .init(
                meetAt: Date(),
                location: "서울 서초구 강남대로69길 8",
                maxParticipants: 5,
                openChatUrl: "https://open.kakao.com/o/sxxxxxx"
            )
        )
    ]

    static func page(query: MyPagePostListQuery) -> MyActivePostPage {
        MyActivePostPage(
            items: posts,
            page: query.page,
            hasNext: false
        )
    }

    static func terms(for termsType: String) -> MyPageTerms {
        switch termsType.uppercased() {
        case "PRIVACY":
            return MyPageTerms(
                id: "11",
                link: "https://makeus-challenge.notion.site/privacy",
                isMandatory: true
            )
        case "SERVICE":
            return MyPageTerms(
                id: "10",
                link: "https://makeus-challenge.notion.site/service",
                isMandatory: true
            )
        default:
            return MyPageTerms(
                id: "0",
                link: "https://makeus-challenge.notion.site/",
                isMandatory: false
            )
        }
    }
}
