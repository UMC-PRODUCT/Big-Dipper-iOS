//
//  StubSessionFixtures.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import CoreDomain
import Foundation
import HomeDomain
import NoticeDomain
import UMCFoundation

/// stub 세션에서 사용하는 픽스처 데이터 모음 (단일 파일 집약).
///
/// 서버 정수 필드는 절대규칙 #2에 따라 전부 `String`으로 유지한다.
/// UI 확인용 데이터를 조정할 때는 이 파일만 수정하면 된다.
enum StubSessionFixtures {

    // MARK: - Profile

    /// 부트스트랩 승인 판정(`isApproved` = `generations` 비어있지 않음)을 통과하는 프로필.
    ///
    /// - Note: 관리자 UI 테스트가 필요하면 `roles`의 `roleType`을
    ///   `.schoolPresident` 등으로 바꾸면 된다 — `SyncProfileStorageUseCase`(실물)가
    ///   `UserSessionManager.currentRole`에 그대로 반영한다.
    static let profile = Profile(
        memberId: "1",
        name: "김유엠",
        nickname: "유엠",
        generations: ["12", "11"],
        schoolId: "3",
        schoolName: "한성대학교",
        latestChallengerId: "100",
        latestGisuId: "10",
        chapterId: "2",
        chapterName: "GACI",
        responsiblePart: "IOS",
        roles: [
            ProfileRole(
                id: "1",
                challengerId: "100",
                gisu: "12",
                gisuId: "10",
                roleType: .challenger,
                organizationType: .school,
                organizationId: "3",
                responsiblePart: "IOS"
            )
        ],
        email: "stub@umc.test"
    )

    // MARK: - Home

    /// 홈 시즌 카드/세대별 상벌점 카드 픽스처 (HomeView #Preview 데이터 기반).
    static let homeProfileResult = HomeProfileResult(
        memberId: "1",
        seasonTypes: [.gens(["11", "12"]), .days(128)],
        generations: [
            HomeGeneration(
                gisuId: "10",
                gen: "12",
                penaltyPoint: 6,
                rewardPoint: 5,
                pointLogs: [
                    PointLog(id: "1", reason: "스터디 지각", date: "03.26", point: -2, isReward: false),
                    PointLog(id: "2", reason: "우수 워크북", date: "03.28", point: 2, isReward: true),
                    PointLog(id: "3", reason: "세미나 무단 결석", date: "04.02", point: -4, isReward: false),
                    PointLog(id: "4", reason: "데모데이 우수팀", date: "04.15", point: 3, isReward: true),
                ]
            ),
            HomeGeneration(gisuId: "9", gen: "11", penaltyPoint: 0, rewardPoint: 4, pointLogs: [
                PointLog(id: "5", reason: "회의록 우수 작성", date: "10.11", point: 4, isReward: true)
            ]),
        ]
    )

    // MARK: - Notice

    /// 최근 공지 목록 픽스처 (홈 최근 공지 5건 + 상세 화면 공용).
    ///
    /// 첨부 이미지는 실제 URL 로드가 발생하지 않도록 빈 배열로 둔다.
    static let notices: [NoticeItemModel] = [
        NoticeItemModel(
            noticeId: "9001",
            generation: "12",
            scope: .central,
            category: .general,
            mustRead: true,
            isAlert: true,
            date: Date(timeIntervalSinceNow: -3_600),
            title: "12기 중앙 해커톤 일정 안내",
            content: """
            안녕하세요, 중앙운영사무국입니다.

            12기 중앙 해커톤 일정을 안내드립니다. 이번 해커톤은 전국 지부가 함께 참여하는 \
            연합 행사로 진행되며, 참가 신청은 이번 주 금요일까지입니다.

            - 일시: 8월 23일(토) ~ 24일(일)
            - 장소: 추후 공지
            - 준비물: 노트북, 열정

            자세한 내용은 첨부 링크를 확인해주세요.
            """,
            writer: "운영진",
            authorNickname: "메이커",
            authorName: "김중앙",
            links: ["https://umc.makeus.in"],
            images: [],
            vote: vote,
            viewCount: "128"
        ),
        NoticeItemModel(
            noticeId: "9002",
            generation: "12",
            scope: .branch,
            category: .general,
            mustRead: false,
            isAlert: false,
            date: Date(timeIntervalSinceNow: -14_400),
            title: "GACI 지부 연합 스터디 모집",
            content: """
            GACI 지부에서 파트별 연합 스터디를 모집합니다.

            iOS / Android / Web / Server 파트별로 주 1회 진행되며, \
            타 학교 챌린저와 함께 성장할 수 있는 기회입니다.
            """,
            writer: "지부장",
            authorNickname: "가치",
            authorName: "박지부",
            links: [],
            images: [],
            vote: nil,
            viewCount: "56",
            scopeDisplayName: "GACI"
        ),
        NoticeItemModel(
            noticeId: "9003",
            generation: "12",
            scope: .campus,
            category: .part(.front(type: .ios)),
            mustRead: true,
            isAlert: false,
            date: Date(timeIntervalSinceNow: -86_400),
            title: "iOS 파트 주차별 워크북 제출 안내",
            content: """
            iOS 파트 챌린저 여러분, 이번 주 워크북 제출 마감은 일요일 23시 59분입니다.

            제출이 늦어지면 벌점이 부과되니 기한을 꼭 지켜주세요.
            """,
            writer: "파트장",
            authorNickname: "스위프트",
            authorName: "이파트",
            links: [],
            images: [],
            vote: nil,
            viewCount: "34",
            scopeDisplayName: "한성대",
            parts: [.front(type: .ios)]
        ),
        NoticeItemModel(
            noticeId: "9004",
            generation: "12",
            scope: .campus,
            category: .general,
            mustRead: false,
            isAlert: false,
            date: Date(timeIntervalSinceNow: -172_800),
            title: "동아리방 이용 수칙 안내",
            content: "동아리방 이용 후에는 정리정돈을 부탁드립니다. 다음 사용자를 위한 배려입니다.",
            writer: "총무",
            authorNickname: "정리왕",
            authorName: "최총무",
            links: [],
            images: [],
            vote: nil,
            viewCount: "21",
            scopeDisplayName: "한성대"
        ),
        NoticeItemModel(
            noticeId: "9005",
            generation: "12",
            scope: .central,
            category: .general,
            mustRead: false,
            isAlert: false,
            date: Date(timeIntervalSinceNow: -259_200),
            title: "8월 회비 납부 안내",
            content: "8월 회비 납부 기한은 8월 10일까지입니다. 계좌는 개별 안내를 확인해주세요.",
            writer: "운영진",
            authorNickname: "메이커",
            authorName: "김중앙",
            links: [],
            images: [],
            vote: nil,
            viewCount: "87"
        ),
    ]

    /// 해커톤 공지에 첨부되는 투표 픽스처 (상세 화면 투표 UI 확인용).
    static let vote = NoticeVote(
        id: "500",
        question: "해커톤 참가 의사를 알려주세요",
        options: [
            VoteOption(id: "1", title: "참가", voteCount: "18"),
            VoteOption(id: "2", title: "불참", voteCount: "4"),
            VoteOption(id: "3", title: "미정", voteCount: "6"),
        ],
        startDate: Date(timeIntervalSinceNow: -86_400),
        endDate: Date(timeIntervalSinceNow: 604_800),
        allowMultipleChoices: false,
        isAnonymous: true,
        userVotedOptionIds: []
    )

    /// noticeId → 상세 픽스처. 목록 아이템과 동일 데이터로 상세를 구성해 정합을 보장한다.
    static let noticeDetails: [String: NoticeDetail] = Dictionary(
        uniqueKeysWithValues: notices.map { ($0.noticeId, $0.toNoticeDetail()) }
    )

    /// 열람 통계 픽스처 (The Ping).
    static let readStatics = NoticeReadStatics(
        totalCount: "42",
        readCount: "35",
        unreadCount: "7",
        readRate: "83.3"
    )

    /// 열람 현황 상세 픽스처.
    static let readStatusPage = NoticeReadStatusPage(
        users: [
            ReadStatusUser(
                id: "1",
                name: "김유엠",
                nickName: "유엠",
                part: "iOS",
                branch: "GACI",
                campus: "한성대",
                profileImageURL: nil,
                isRead: true
            ),
            ReadStatusUser(
                id: "2",
                name: "박챌린",
                nickName: "챌린",
                part: "Android",
                branch: "GACI",
                campus: "한성대",
                profileImageURL: nil,
                isRead: false
            ),
        ],
        nextCursor: "",
        hasNext: false
    )

    // MARK: - Schedule

    /// 일정 생성 stub 이 돌려주는 고정 식별자.
    static let createdScheduleId = "9001"

    /// 요청 기간(`from ~ to`) 안에 상대 날짜로 일정 픽스처를 생성한다.
    ///
    /// 달을 이동해도 항상 일정이 보이도록 기간 기준으로 며칠을 골라 채우고,
    /// 오늘이 기간에 포함되면 오늘 일정도 추가한다 (홈 진입 직후 리스트 확인용).
    static func schedules(from: Date, to: Date) -> [Date: [ScheduleDetailData]] {
        let calendar = Calendar.kstGregorian
        var result: [Date: [ScheduleDetailData]] = [:]

        let templates: [(dayOffset: Int, name: String, tags: [String], isOnline: Bool)] = [
            (2, "iOS 파트 정기 스터디", ["스터디"], false),
            (9, "중앙 연합 세미나", ["세미나"], true),
            (16, "지부 네트워킹 데이", ["네트워킹"], false),
            (23, "운영진 정기 회의", ["회의"], true),
        ]

        for (index, template) in templates.enumerated() {
            guard
                let day = calendar.date(byAdding: .day, value: template.dayOffset, to: from),
                day <= to
            else { continue }
            appendSchedule(
                id: "80\(index)",
                name: template.name,
                tags: template.tags,
                isOnline: template.isOnline,
                on: day,
                calendar: calendar,
                into: &result
            )
        }

        let today = Date.now
        if today >= from, today <= to {
            appendSchedule(
                id: "899",
                name: "홈 화면 QA 모각작",
                tags: ["스터디"],
                isOnline: false,
                on: today,
                calendar: calendar,
                into: &result
            )
        }

        return result
    }

    // MARK: - Private Function

    /// 지정 날짜 19:00(KST) 시작, 2시간짜리 일정을 만들어 날짜 버킷에 추가한다.
    private static func appendSchedule(
        id: String,
        name: String,
        tags: [String],
        isOnline: Bool,
        on day: Date,
        calendar: Calendar,
        into result: inout [Date: [ScheduleDetailData]]
    ) {
        let bucket = calendar.startOfDay(for: day)
        let startsAt = calendar.date(
            bySettingHour: 19, minute: 0, second: 0, of: day
        ) ?? day
        let schedule = ScheduleDetailData(
            scheduleId: id,
            name: name,
            description: "stub 세션 일정입니다. UI 확인용 데이터로, 서버와 무관합니다.",
            tags: tags,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(7_200),
            isParticipant: true,
            isOnline: isOnline
        )
        result[bucket, default: []].append(schedule)
    }
}
#endif
