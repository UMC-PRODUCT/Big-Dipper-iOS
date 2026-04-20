//
//  CommunityMockData.swift
//  AppProduct
//

import Foundation

/// 게스트 세션 및 프리뷰용 커뮤니티 Mock 데이터
enum CommunityMockData {

    // MARK: - Posts

    static let posts: [CommunityItemModel] = [
        CommunityItemModel(
            postId: 1001,
            userId: 101,
            category: .free,
            title: "UMC 9기 시작하신 분들 화이팅!",
            content: "9기 OT 다녀왔는데 분위기 너무 좋았어요. 이번 기수도 잘 부탁드립니다 🙌",
            profileImage: nil,
            userName: "홍길동",
            userNickname: "길동이",
            part: .front(type: .ios),
            createdAt: Date().addingTimeInterval(-60 * 30),
            likeCount: 42,
            commentCount: 5,
            scrapCount: 3,
            isLiked: false,
            isScrapped: false,
            isAuthor: false,
            lightningInfo: nil
        ),
        CommunityItemModel(
            postId: 1002,
            userId: 102,
            category: .question,
            title: "SwiftUI @Observable 마이그레이션 질문",
            content: "@StateObject에서 @State로 바꿀 때 기존 @Published는 어떻게 정리하시나요?",
            profileImage: nil,
            userName: "김미주",
            userNickname: "마티",
            part: .front(type: .ios),
            createdAt: Date().addingTimeInterval(-60 * 60 * 2),
            likeCount: 13,
            commentCount: 4,
            scrapCount: 1,
            isLiked: true,
            isScrapped: false,
            isAuthor: false,
            lightningInfo: nil
        ),
        CommunityItemModel(
            postId: 1003,
            userId: 103,
            category: .lighting,
            title: "⚡️ 강남역 번개 스터디 모집",
            content: "iOS 아키텍처 얘기하실 분 3명 모집합니다. 커피값은 각자!",
            profileImage: nil,
            userName: "박준혁",
            userNickname: "제이",
            part: .front(type: .ios),
            createdAt: Date().addingTimeInterval(-60 * 60 * 5),
            likeCount: 7,
            commentCount: 2,
            scrapCount: 0,
            isLiked: false,
            isScrapped: false,
            isAuthor: false,
            lightningInfo: CommunityLightningInfo(
                meetAt: Date().addingTimeInterval(60 * 60 * 24 * 2),
                location: "서울 강남구 강남대로 지하역",
                maxParticipants: 4,
                openChatUrl: "https://open.kakao.com/o/sample"
            )
        ),
        CommunityItemModel(
            postId: 1004,
            userId: 104,
            category: .information,
            title: "iOS 파트 Xcode 26 Beta 후기",
            content: "Liquid Glass API가 생각보다 쾌적해요. 다만 List는 여전히 주의가 필요합니다.",
            profileImage: nil,
            userName: "이예지",
            userNickname: "소피",
            part: .front(type: .ios),
            createdAt: Date().addingTimeInterval(-60 * 60 * 26),
            likeCount: 21,
            commentCount: 3,
            scrapCount: 5,
            isLiked: false,
            isScrapped: true,
            isAuthor: false,
            lightningInfo: nil
        ),
        CommunityItemModel(
            postId: 1005,
            userId: 105,
            category: .habit,
            title: "매일 1커밋 챌린지 3일차",
            content: "오늘은 에러 핸들러 리팩토링 했어요. 같이 하실 분 댓글 주세요!",
            profileImage: nil,
            userName: "정의찬",
            userNickname: "제옹",
            part: .pm,
            createdAt: Date().addingTimeInterval(-60 * 60 * 48),
            likeCount: 9,
            commentCount: 1,
            scrapCount: 0,
            isLiked: false,
            isScrapped: false,
            isAuthor: false,
            lightningInfo: nil
        )
    ]

    // MARK: - Comments

    static let comments: [CommunityCommentModel] = [
        CommunityCommentModel(
            commentId: 1,
            userId: 201,
            profileImage: nil,
            userName: "박경운",
            userNickname: "하늘",
            content: "좋은 글 감사합니다! 저도 많이 배워갑니다.",
            createdAt: Date().addingTimeInterval(-60 * 10),
            isAuthor: false
        ),
        CommunityCommentModel(
            commentId: 2,
            userId: 202,
            profileImage: nil,
            userName: "강하나",
            userNickname: "와나",
            content: "공감합니다 🙌",
            createdAt: Date().addingTimeInterval(-60 * 30),
            isAuthor: false
        )
    ]

    // MARK: - Trophies

    static let trophies: [CommunityFameItemModel] = [
        CommunityFameItemModel(
            week: 1,
            university: "UMC 대학교",
            profileImage: nil,
            userName: "이예지",
            part: .front(type: .ios),
            workbookTitle: "SwiftUI 화면 구성 및 상태 관리",
            content: "@State/@Binding 기반 카드 UI 구현 및 네비게이션 연결까지 깔끔하게 수행했습니다.",
            url: "https://github.com/example/workbook-1"
        ),
        CommunityFameItemModel(
            week: 2,
            university: "UMC 대학교",
            profileImage: nil,
            userName: "박경운",
            part: .server(type: .spring),
            workbookTitle: "Spring Boot REST API 설계",
            content: "도메인 분리와 예외 처리 컨벤션이 인상적입니다.",
            url: "https://github.com/example/workbook-2"
        ),
        CommunityFameItemModel(
            week: 3,
            university: "UMC 대학교",
            profileImage: nil,
            userName: "양지애",
            part: .design,
            workbookTitle: "모바일 내비게이션 디자인",
            content: "사용성 테스트 기반으로 IA를 재구성한 사례가 훌륭합니다.",
            url: "https://github.com/example/workbook-3"
        )
    ]

    // MARK: - Helpers

    static func fallbackPost(postId: Int) -> CommunityItemModel {
        CommunityItemModel(
            postId: postId,
            userId: 0,
            category: .free,
            title: "게스트 모드 게시글",
            content: "게스트 모드에서 표시되는 Mock 게시글입니다.",
            profileImage: nil,
            userName: "홍길동",
            userNickname: "길동이",
            part: .front(type: .ios),
            createdAt: Date(),
            likeCount: 0,
            commentCount: 0,
            scrapCount: 0,
            isLiked: false,
            isScrapped: false,
            isAuthor: false,
            lightningInfo: nil
        )
    }
}
