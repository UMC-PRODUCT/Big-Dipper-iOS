//
//  NoticeMockData.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//
//9th UMC Hackathon 모집 신청 안내
import Foundation

// MARK: - Notice Mock Data
enum NoticeMockData {
    static let items: [NoticeItemModel] = [
        NoticeItemModel(
            generation: 9,
            scope: .central,
            category: .general,
            isAlert: true,
            date: Date(),
            title: "9th UMC Hackathon 모집 신청 안내",
            content: """
            안녕하세요 9기 UMC 중앙운영사무국입니다!
            챌린저 여러분께서 기다리시던 9th UMC Hackathon이 진행됩니다! 🫧 😉
            
            UMC 해커톤이 끝난 후 여러분은 피곤함과 퀭한 눈, 빈 커피 잔과 빌드 에러, 엉킨 Git 커밋과 퇴화한 의사소통, 조금 더 심해진 거북목.. 그리고 처음부터 끝까지 만들어낸 나의 서비스, 최고의 팀원들, 꽤 오래 남을 뿌듯함과 함께 돌아가실 수 있습니다!
            
            🫧 UMC Hackathon 주요 일정
            
            일시  1월 10일(토) 13시 ~ 11일(일) 13시 30분
            장소  선릉 디캠프 6층 다목적홀
            대상  UMC 9기 챌린저, 운영진 및 OB (1~8기)
            
            🫧 UMC Hackathon 모집 신청
            
            신청 마감 ~ 12월 26일(금) 23시 59분
            취소 기간  12월 27일(토) ~ 28일(일) 23시 59분
            해커톤 신청은 선착순으로 진행되니, 서둘러 신청해주세요!
            모집 신청 바로가기
            
            🫧  참가자 안내 사항
            
            파트별 필요인원이 다릅니다. 신청 마감 이후, 확정 인원을 대상으로 카카오톡 방에 초대해 드리겠습니다.
            본 행사 노쇼 시 추후 다른 행사 참여시 불이익이 있을 수 있습니다. 노쇼 절대 금지!
            관련 문의는 UMC 카카오톡 채널 로 주시길 바랍니다.
            """,
            writer: "사과/김아요-9th UMC 총괄",
            links: ["https://docs.google.com/forms/d/e/1FAIpQLScMRkzedDWNEomxuOhhOzOXbVXK3xcA5Afevsi8dDkaDmqxKA/viewform"],
            images: [],
            vote: nil,
            viewCount: 445
        ),
        
        NoticeItemModel(
            generation: 9,
            scope: .central,
            category: .general,
            isAlert: true,
            date: Date(),
            title: "🗣️ 9th UMC 동아리 연합 컨퍼런스 신청 모집 안내 🗣️",
            content: """
            안녕하세요, 9기 UMC 중앙운영사무국입니다! 😉💓  2026년 9th UMCON이 다가오고 있습니다!
            이번 9th UMCON은  UMC 챌린저 여러분을 대상으로 IT & 프로덕트 개발 관련 다양한 인사이트를 제공하고자 기획된 컨퍼런스입니다.  IT와 프로덕트 개발에 관심 있는 분들의 많은 참여를 기다립니다 ✨
            
            UMCON이란?
            현업자 혹은 시니어 PM / 디자이너 / 개발자 분들의  강연과 네트워킹이 함께 이루어지는 UMC 대표 컨퍼런스 행사입니다!
            
            이 기회를 꼭 놓치지 마세요!  놓치면 정말 손해인 행사입니다!!  꼭 참여해서 많은 인사이트를 얻어가시길 바랍니다 🙌
            
            🔥 컨퍼런스 행사 개요
            행사 일시: 2026년 1월 24일 (토)
            행사 장소: 시립 보라매 청소년 센터( 슬기 102, 슬기 107, 슬기 207, 큰나무 207)
            신청 기한:  2025년 1월 5일 (월) ~ 2026년 1월 12일 (월) 23:59
            취소 기한:  2026년 1월 14일 (수) 23:59까지   (UMC 카카오톡 문의 채널)
            참가 대상: UMC 챌린저 및 OB
            참가 비용: 1,000원 (노쇼 방지용)
            👉 신청 구글폼 바로가기
            
            😃 컨퍼런스는 어떻게 진행될까요?
            1️⃣ 다양한 파트와 세션컨퍼런스는 다음 4가지 파트로 나뉘어 진행됩니다.
            기획 & 디자인 파트
            프론트엔드 파트 (Web / iOS / Android)
            백엔드 파트 (Server - Spring / Node.js)
            AI 파트
            각 파트에서 뛰어난 업계 실무자들의  강연과 질의응답 세션이 준비되어 있습니다.
            2️⃣ 자유로운 세션 선택
            본인의 파트 외에도 관심 있는 세션 자유롭게 청강 가능
            행사 당일,  자유롭게 오가며 참여 가능합니다.
            3️⃣ 네트워킹 진행
            14:00부터 강연 참가자들과 함께 네트워킹 진행🎮 게임을 통해 다양한 상품 획득 기회도 준비되어 있으니  많은 참여 부탁드립니다!
            4️⃣ 세션 구성
            각 세션은 강연 + Q&A 포함 20-30분으로 구성됩니다.
            5️⃣ 뒤풀이 안내
            행사 종료 후, 참가자들과 네트워킹을 위한 뒤풀이가 예정되어 있습니다.
            참여 여부를 미리 조사할 예정이며,  뒷풀이 참가비는 5,000원입니다.
            식사 비용은 전체적으로 부담 예정입니다.
            6️⃣ 공지 안내
            행사 확정 인원은 2026년 1월 13일 (화)에 공지될 예정입니다.
            확정 공지는 카카오톡 팀 채팅을 통해 발송되며,  반드시 카카오톡을 통해 확인해주시길 바랍니다.
            
            주의사항
            지정된 시간 외 제출된 폼은 인정되지 않습니다.
            선착순 모집으로, 신청 인원이 많을 )경우 조기 마감될 수 있으니  빠른 신청 부탁드립니다 🙂
            
            📷 촬영 안내
            행사 기록 및 스케치 영상 제작을 위해  사진 및 영상 촬영이 진행될 예정입니다.  얼굴은 모자이크 처리될 예정이니 부담 없이 참여해주세요 😊
            
            챌린저 여러분의 많은 관심과 참여 부탁드립니다 🥰🔥
            """,
            writer: "사과/김아요-9th UMC 총괄",
            links: ["https://docs.google.com/forms/d/e/1FAIpQLSdNlFIiWoxTwFb6M-inX_Sjf-Icjr-XbkFjcGmzpNL4bRF-2Q/viewform"],
            images: [],
            vote: nil,
            viewCount: 421
        ),
        
        // 1. 투표 포함 공지
        NoticeItemModel(
            generation: 9,
            scope: .campus,
            category: .general,
            isAlert: false,
            date: Date(),
            title: "[투표] 9기 기말고사 뒤풀이 메뉴 선정 안내",
            content: """
            9기 UMC대 챌린저 여러분 안녕하세요! 애플입니다☺️ 기말고사 뒤풀이로 진행될 회식 메뉴를 결정하고자 합니다. 가장 많은 표를 받은 메뉴로 진행됩니다!
            """,
            writer: "애플/박사과-9th UMC대 회장",
            links: [],
            images: [],
            vote: NoticeVote(
                id: "vote1",
                question: "회식 메뉴를 선택해주세요",
                options: [
                    VoteOption(id: "1", title: "삼겹살", voteCount: 15),
                    VoteOption(id: "2", title: "치킨", voteCount: 9),
                    VoteOption(id: "3", title: "피자", voteCount: 5),
                ],
                startDate: Date(),
                endDate: Date(timeIntervalSinceNow: 86400 * 7),
                allowMultipleChoices: false,
                isAnonymous: true,
                userVotedOptionIds: []
            ),
            viewCount: 32
        ),
        
        // 2. 이미지 포함 공지
        NoticeItemModel(
            generation: 9,
            scope: .central,
            category: .general,
            isAlert: false,
            date: Date(),
            title: "9기 해커톤 현장 사진 공유",
            content: "지난 주말 진행된 해커톤 현장 사진을 공유합니다. 모두 고생하셨습니다!",
            writer: "너드/이서버-9th UMC 부총괄",
            links: [],
            images: [
                "https://picsum.photos/400/400",
                "https://picsum.photos/400/401",
                "https://picsum.photos/400/402",
                "https://picsum.photos/400/403",
                "https://picsum.photos/400/404"
            ],
            vote: nil,
            viewCount: 256
        ),
    ]
    
    // MARK: - Read Status Mock Data
    
    /// 교내 공지 대상 사용자 목록
    static let campusUsers: [ReadStatusUser] = [
        // 확인함 (32명)
        // iOS 파트 (6명 중 5명 확인)
        ReadStatusUser(id: "user1", name: "이예지", nickName: "소피", part: "iOS", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user2", name: "김미주", nickName: "마티", part: "iOS", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user3", name: "이재원", nickName: "리버", part: "iOS", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user4", name: "박준혁", nickName: "제이", part: "iOS", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user5", name: "최서연", nickName: "세리", part: "iOS", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user6", name: "정다은", nickName: "다니", part: "iOS", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        
        // Android 파트 (7명 중 5명 확인)
        ReadStatusUser(id: "user7", name: "박유수", nickName: "어헛차", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user8", name: "조경석", nickName: "조나단", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user9", name: "김동현", nickName: "도니", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user10", name: "이승우", nickName: "승승", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user11", name: "한지민", nickName: "지미", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user12", name: "오민석", nickName: "민이", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        ReadStatusUser(id: "user13", name: "신예은", nickName: "예니", part: "Android", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        
        // Spring Boot 파트 (10명 중 8명 확인)
        ReadStatusUser(id: "user14", name: "박경운", nickName: "하늘", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user15", name: "강하나", nickName: "와나", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user16", name: "박지현", nickName: "박박지현", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user17", name: "이현수", nickName: "현이", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user18", name: "윤서준", nickName: "서준", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user19", name: "장민지", nickName: "민지", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user20", name: "홍길동", nickName: "길동", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user21", name: "김태희", nickName: "태희", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user22", name: "최민호", nickName: "민호", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        ReadStatusUser(id: "user23", name: "정수아", nickName: "수아", part: "Spring Boot", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        
        // Node.js 파트 (8명 중 6명 확인)
        ReadStatusUser(id: "user24", name: "박세은", nickName: "세니", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user25", name: "이예은", nickName: "스읍", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user26", name: "김준호", nickName: "준호", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user27", name: "이소라", nickName: "소라", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user28", name: "박도윤", nickName: "도윤", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user29", name: "강민수", nickName: "민수", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user30", name: "최유진", nickName: "유진", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        ReadStatusUser(id: "user31", name: "한서윤", nickName: "서윤", part: "Node.js", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        
        // Design 파트 (6명 중 4명 확인)
        ReadStatusUser(id: "user32", name: "이희원", nickName: "삼이", part: "Design", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user33", name: "양지애", nickName: "나루", part: "Design", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user34", name: "정하윤", nickName: "하윤", part: "Design", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user35", name: "김시우", nickName: "시우", part: "Design", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user36", name: "박예진", nickName: "예진", part: "Design", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        ReadStatusUser(id: "user37", name: "이준서", nickName: "준서", part: "Design", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false),
        
        // PM 파트 (5명 중 4명 확인)
        ReadStatusUser(id: "user38", name: "정의찬", nickName: "제옹", part: "PM", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user39", name: "김도연", nickName: "도리", part: "PM", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user40", name: "이지훈", nickName: "지훈", part: "PM", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user41", name: "박소연", nickName: "소연", part: "PM", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: true),
        ReadStatusUser(id: "user42", name: "최윤아", nickName: "윤아", part: "PM", branch: "Nova", campus: "UMC대", profileImageURL: nil, isRead: false)
    ]
    
    /// 공지 ID별 수신 확인 현황 생성
    static func readStatus(for noticeId: String) -> NoticeReadStatus {
        // 교내 공지 수신 확인 현황 (32명 확인 / 10명 미확인)
        return NoticeReadStatus(
            noticeId: noticeId,
            confirmedUsers: campusUsers.filter { $0.isRead },
            unconfirmedUsers: campusUsers.filter { !$0.isRead }
        )
    }
}
