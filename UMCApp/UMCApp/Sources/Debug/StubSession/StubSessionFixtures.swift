//
//  StubSessionFixtures.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
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
    /// ``StubPersona`` 로 갈린다 — 명함 교환 검증은 두 기기가 서로 다른 사람이어야 성립한다.
    ///
    /// - Note: 관리자 UI 테스트가 필요하면 `roles`의 `roleType`을
    ///   `.schoolPresident` 등으로 바꾸면 된다 — `SyncProfileStorageUseCase`(실물)가
    ///   `UserSessionManager.currentRole`에 그대로 반영한다.
    static var profile: Profile {
        switch StubPersona.current {
        case .a: return personaAProfile
        case .b: return personaBProfile
        }
    }

    private static let personaAProfile = Profile(
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
                roleType: .schoolPresident,
                organizationType: .school,
                organizationId: "3",
                responsiblePart: "IOS"
            )
        ],
        email: "stub@umc.test",
        externalLinks: ProfileExternalLinks(
            id: "1",
            linkedIn: "linkedin.com/in/umc-a",
            instagram: nil,
            github: "github.com/umc-a",
            blog: "umc-a.tistory.com",
            personal: nil
        )
    )

    /// 두 번째 신원. **모든 표시 필드가 A와 다르다** — 이름·학교·파트·기수·외부 링크까지.
    /// 받은 명함이 자기 것인지 상대 것인지 화면만 보고 갈리게 하려는 것이다.
    private static let personaBProfile = Profile(
        memberId: "2",
        name: "박챌린",
        nickname: "챌린",
        generations: ["11"],
        schoolId: "5",
        schoolName: "중앙대학교",
        latestChallengerId: "200",
        latestGisuId: "9",
        chapterId: "2",
        chapterName: "GACI",
        // `UMCPartType(apiValue:)` 가 받는 문자열이어야 한다. 틀리면 조용히 `.admin` 으로
        // 떨어져 명함이 「운영진」으로 보인다 — 실기기 검증에서 실제로 그랬다.
        responsiblePart: "SPRINGBOOT",
        roles: [
            ProfileRole(
                id: "2",
                challengerId: "200",
                gisu: "11",
                gisuId: "9",
                roleType: .schoolPresident,
                organizationType: .school,
                organizationId: "5",
                responsiblePart: "SPRINGBOOT"
            )
        ],
        email: "stub-b@umc.test",
        externalLinks: ProfileExternalLinks(
            id: "2",
            linkedIn: "linkedin.com/in/umc-b",
            instagram: nil,
            github: "github.com/umc-b",
            blog: "umc-b.velog.io",
            personal: nil
        )
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

    // MARK: - Study

    /// 챌린저 스터디 탭의 커리큘럼/미션 픽스처.
    ///
    /// stub 프로필의 기수·파트가 실제 서버 데이터와 일치하지 않아도 활동 탭을 확인할 수
    /// 있도록 결과를 고정한다.
    static let curriculumOverview = CurriculumOverview(
        progress: CurriculumProgressModel(
            partType: .front(type: .ios),
            partName: "iOS PART CURRICULUM",
            curriculumTitle: "iOS 챌린저 커리큘럼",
            completedCount: 3,
            totalCount: 8
        ),
        missions: [
            MissionCardModel(
                week: 1,
                platform: "iOS",
                title: "SwiftUI 기본 개념",
                missionTitle:
                    "SwiftUI 기본 개념을 학습하고 정리한 글 링크를 " +
                    "제출하세요",
                status: .pass
            ),
            MissionCardModel(
                week: 2,
                platform: "iOS",
                title: "상태 관리와 데이터 흐름",
                missionTitle: "@State와 @Binding을 활용한 화면을 구현하세요",
                status: .pass
            ),
            MissionCardModel(
                week: 3,
                platform: "iOS",
                title: "Swift Concurrency",
                missionTitle: "async/await를 적용한 비동기 작업을 제출하세요",
                status: .pass
            ),
            MissionCardModel(
                week: 4,
                platform: "iOS",
                title: "네트워크 레이어 설계",
                missionTitle: "Moya를 활용한 API 호출 예제를 제출하세요",
                status: .inProgress
            ),
            MissionCardModel(
                week: 5,
                platform: "iOS",
                title: "재사용 가능한 컴포넌트",
                missionTitle: "공통 UI 컴포넌트를 설계하고 적용하세요",
                status: .notStarted
            )
        ]
    )

    /// 스터디 일정 등록 화면에서 고르는 주차 옵션 픽스처.
    static let weeklyCurriculumOptions: [WeeklyCurriculumOption] = [
        WeeklyCurriculumOption(
            weeklyCurriculumId: "1001",
            weekNo: "1",
            title: "SwiftUI 기본 개념"
        ),
        WeeklyCurriculumOption(
            weeklyCurriculumId: "1002",
            weekNo: "2",
            title: "상태 관리와 데이터 흐름"
        ),
        WeeklyCurriculumOption(
            weeklyCurriculumId: "1003",
            weekNo: "3",
            title: "Swift Concurrency"
        ),
        WeeklyCurriculumOption(
            weeklyCurriculumId: "1004",
            weekNo: "4",
            title: "네트워크 레이어 설계"
        ),
        WeeklyCurriculumOption(
            weeklyCurriculumId: "1005",
            weekNo: "5",
            title: "재사용 가능한 컴포넌트"
        )
    ]

    /// 운영진 스터디 그룹 관리 화면 픽스처. 멘토 1명 + 스터디원을 둔 그룹 2개.
    static let studyGroups: [StudyGroupInfo] = [
        StudyGroupInfo(
            serverID: "601",
            name: "iOS 심화 스터디",
            part: .front(type: .ios),
            createdDate: Date(timeIntervalSinceNow: -86_400 * 14),
            mentors: [
                StudyGroupMember(
                    serverID: "201",
                    challengerID: "301",
                    memberID: "201",
                    name: "이파트",
                    nickname: "스위프트",
                    university: "한성대학교",
                    role: .leader,
                    bestWorkbookPoint: 3
                )
            ],
            members: [
                StudyGroupMember(
                    serverID: "211",
                    challengerID: "311",
                    memberID: "211",
                    name: "김스위",
                    nickname: "옵셔널",
                    university: "한성대학교",
                    role: .member,
                    bestWorkbookPoint: 2
                ),
                StudyGroupMember(
                    serverID: "212",
                    challengerID: "312",
                    memberID: "212",
                    name: "윤클로",
                    nickname: "클로저",
                    university: "한성대학교",
                    role: .member,
                    bestWorkbookPoint: 1
                ),
            ]
        ),
        StudyGroupInfo(
            serverID: "602",
            name: "Android 기초 스터디",
            part: .front(type: .android),
            createdDate: Date(timeIntervalSinceNow: -86_400 * 7),
            mentors: [
                StudyGroupMember(
                    serverID: "202",
                    challengerID: "302",
                    memberID: "202",
                    name: "박안드",
                    nickname: "코틀린",
                    university: "한성대학교",
                    role: .leader,
                    bestWorkbookPoint: 2
                )
            ],
            members: [
                StudyGroupMember(
                    serverID: "221",
                    challengerID: "321",
                    memberID: "221",
                    name: "오코루",
                    nickname: "코루틴",
                    university: "한성대학교",
                    role: .member,
                    bestWorkbookPoint: 0
                )
            ]
        ),
    ]

    /// 스터디원 제출 현황 픽스처. `weeklyCurriculumOptions` 와 같은 주차 식별자를 공유한다.
    static let studyMemberSubmissions: [StudyMemberSubmission] = [
        StudyMemberSubmission(
            studyGroupMemberId: "211",
            memberId: "211",
            memberName: "김스위",
            nickname: "옵셔널",
            schoolName: "한성대학교",
            studyGroupId: "601",
            studyGroupName: "iOS 심화 스터디",
            part: .front(type: .ios),
            partLabel: "iOS",
            weeks: [
                WeeklySubmission(
                    weekNo: "1",
                    weeklyCurriculumId: "1001",
                    challengerWorkbookId: "5001",
                    status: .pass,
                    isBest: true
                ),
                WeeklySubmission(
                    weekNo: "2",
                    weeklyCurriculumId: "1002",
                    challengerWorkbookId: "5002",
                    status: .pass
                ),
                WeeklySubmission(
                    weekNo: "3",
                    weeklyCurriculumId: "1003",
                    status: .notSubmitted
                ),
            ]
        ),
        StudyMemberSubmission(
            studyGroupMemberId: "212",
            memberId: "212",
            memberName: "윤클로",
            nickname: "클로저",
            schoolName: "한성대학교",
            studyGroupId: "601",
            studyGroupName: "iOS 심화 스터디",
            part: .front(type: .ios),
            partLabel: "iOS",
            weeks: [
                WeeklySubmission(
                    weekNo: "1",
                    weeklyCurriculumId: "1001",
                    challengerWorkbookId: "5003",
                    status: .pass
                ),
                WeeklySubmission(
                    weekNo: "2",
                    weeklyCurriculumId: "1002",
                    challengerWorkbookId: "5004",
                    status: .inProgress
                ),
            ]
        ),
        StudyMemberSubmission(
            studyGroupMemberId: "221",
            memberId: "221",
            memberName: "오코루",
            nickname: "코루틴",
            schoolName: "한성대학교",
            studyGroupId: "602",
            studyGroupName: "Android 기초 스터디",
            part: .front(type: .android),
            partLabel: "Android",
            weeks: [
                WeeklySubmission(
                    weekNo: "1",
                    weeklyCurriculumId: "1001",
                    challengerWorkbookId: "5005",
                    status: .fail
                ),
                WeeklySubmission(
                    weekNo: "2",
                    weeklyCurriculumId: "1002",
                    status: .notSubmitted
                ),
            ]
        ),
    ]

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

    // MARK: - Member

    /// 멤버 관리 화면 픽스처 — 파트별 그룹핑 확인용으로 6개 파트를 모두 포함한다.
    static let members: [MemberManagementItem] = [
        MemberManagementItem(
            memberID: "201",
            challengerID: "301",
            profile: nil,
            name: "이파트",
            nickname: "스위프트",
            generation: "12기",
            school: "한성대학교",
            position: "iOS 파트장",
            part: .front(type: .ios),
            penalty: 0,
            rewardPoints: 6,
            badge: true,
            managementTeam: .schoolPartLeader,
            attendanceRecords: [
                MemberAttendanceRecord(
                    sessionTitle: "iOS 파트 정기 스터디",
                    week: 3,
                    status: .present
                ),
                MemberAttendanceRecord(
                    sessionTitle: "중앙 연합 세미나",
                    week: 0,
                    status: .late
                ),
            ],
            penaltyHistory: [
                OperatorMemberPenaltyHistory(
                    challengerPointId: "401",
                    date: Date(timeIntervalSinceNow: -86_400 * 5),
                    reason: "우수 워크북",
                    penaltyScore: 2,
                    pointType: .bestWorkbook
                )
            ],
            generationPoints: [GenerationPointSummary(gisu: 12, reward: 6, penalty: 0)]
        ),
        MemberManagementItem(
            memberID: "202",
            challengerID: "302",
            profile: nil,
            name: "박안드",
            nickname: "코틀린",
            generation: "12기",
            school: "한성대학교",
            position: "Android 파트원",
            part: .front(type: .android),
            penalty: 2,
            rewardPoints: 1,
            badge: false,
            managementTeam: .challenger,
            attendanceRecords: [],
            penaltyHistory: [
                OperatorMemberPenaltyHistory(
                    challengerPointId: "402",
                    date: Date(timeIntervalSinceNow: -86_400 * 8),
                    reason: "스터디 지각",
                    penaltyScore: 2,
                    pointType: .studyLate
                )
            ],
            generationPoints: [GenerationPointSummary(gisu: 12, reward: 1, penalty: 2)]
        ),
        MemberManagementItem(
            memberID: "203",
            challengerID: "303",
            profile: nil,
            name: "최웹",
            nickname: "리액트",
            generation: "11기",
            school: "한성대학교",
            position: "Web 파트원",
            part: .front(type: .web),
            penalty: 0,
            rewardPoints: 2,
            badge: false,
            managementTeam: .challenger,
            attendanceRecords: [],
            penaltyHistory: []
        ),
        MemberManagementItem(
            memberID: "204",
            challengerID: "304",
            profile: nil,
            name: "정서버",
            nickname: "스프링",
            generation: "12기",
            school: "한성대학교",
            position: "Server 파트원",
            part: .server(type: .spring),
            penalty: 4,
            rewardPoints: 0,
            badge: false,
            managementTeam: .challenger,
            attendanceRecords: [],
            penaltyHistory: [
                OperatorMemberPenaltyHistory(
                    challengerPointId: "403",
                    date: Date(timeIntervalSinceNow: -86_400 * 3),
                    reason: "워크북 미제출",
                    penaltyScore: 4,
                    pointType: .noWorkbookMission
                )
            ]
        ),
        MemberManagementItem(
            memberID: "205",
            challengerID: "305",
            profile: nil,
            name: "한디자인",
            nickname: "피그마",
            generation: "12기",
            school: "한성대학교",
            position: "Designer",
            part: .design,
            penalty: 0,
            rewardPoints: 3,
            badge: false,
            managementTeam: .challenger,
            attendanceRecords: [],
            penaltyHistory: []
        ),
        MemberManagementItem(
            memberID: "206",
            challengerID: "306",
            profile: nil,
            name: "조기획",
            nickname: "노션",
            generation: "11기",
            school: "한성대학교",
            position: "PM",
            part: .pm,
            penalty: 0,
            rewardPoints: 0,
            badge: false,
            managementTeam: .schoolVicePresident,
            attendanceRecords: [],
            penaltyHistory: []
        ),
    ]

    // MARK: - Attendance (Operator)

    /// 운영진 출석 관리 화면 픽스처. 오늘 기준 상대 일자라 언제 열어도 최근 데이터로 보인다.
    static func attendanceSchedules() -> [ScheduleAttendanceInfo] {
        let calendar = Calendar.kstGregorian
        let now = Date.now

        func at(_ dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let ongoing = ScheduleAttendanceInfo(
            scheduleId: "7001",
            name: "iOS 파트 정기 스터디",
            description: "stub 세션 출석 픽스처입니다.",
            startsAt: at(0, hour: 19),
            endsAt: at(0, hour: 21),
            location: ScheduleLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                locationName: "한성대학교 상상관"
            ),
            isOnline: false,
            authorMemberId: "201",
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: at(0, hour: 18, minute: 30),
                onTimeEndAt: at(0, hour: 19, minute: 10),
                lateEndAt: at(0, hour: 19, minute: 30)
            ),
            tags: ["스터디"],
            participants: [
                ParticipantAttendance(
                    memberId: "201",
                    name: "이파트",
                    nickname: "스위프트",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .present,
                    isLocationVerified: true,
                    excuseReason: nil
                ),
                ParticipantAttendance(
                    memberId: "211",
                    name: "김스위",
                    nickname: "옵셔널",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .presentPending,
                    isLocationVerified: true,
                    excuseReason: nil
                ),
                ParticipantAttendance(
                    memberId: "212",
                    name: "윤클로",
                    nickname: "클로저",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .latePending,
                    isLocationVerified: true,
                    excuseReason: nil
                ),
                ParticipantAttendance(
                    memberId: "202",
                    name: "박안드",
                    nickname: "코틀린",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .excusedPending,
                    isLocationVerified: false,
                    excuseReason: "팀 프로젝트 마감과 겹쳐 이번 세션은 온라인으로 대체 참여합니다."
                ),
                ParticipantAttendance(
                    memberId: "203",
                    name: "최웹",
                    nickname: "리액트",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .absent,
                    isLocationVerified: false,
                    excuseReason: nil
                ),
            ]
        )

        let past = ScheduleAttendanceInfo(
            scheduleId: "7002",
            name: "중앙 연합 세미나",
            description: "stub 세션 출석 픽스처입니다.",
            startsAt: at(-3, hour: 14),
            endsAt: at(-3, hour: 17),
            location: nil,
            isOnline: true,
            authorMemberId: "201",
            attendancePolicy: nil,
            tags: ["세미나"],
            participants: [
                ParticipantAttendance(
                    memberId: "201",
                    name: "이파트",
                    nickname: "스위프트",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .present,
                    isLocationVerified: true,
                    excuseReason: nil
                ),
                ParticipantAttendance(
                    memberId: "204",
                    name: "정서버",
                    nickname: "스프링",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .late,
                    isLocationVerified: true,
                    excuseReason: nil
                ),
                ParticipantAttendance(
                    memberId: "205",
                    name: "한디자인",
                    nickname: "피그마",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .excused,
                    isLocationVerified: false,
                    excuseReason: "학과 시험 일정과 겹쳐 불참합니다."
                ),
                ParticipantAttendance(
                    memberId: "206",
                    name: "조기획",
                    nickname: "노션",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .absent,
                    isLocationVerified: false,
                    excuseReason: nil
                ),
            ]
        )

        let upcoming = ScheduleAttendanceInfo(
            scheduleId: "7003",
            name: "지부 네트워킹 데이",
            description: "stub 세션 출석 픽스처입니다.",
            startsAt: at(10, hour: 18),
            endsAt: at(10, hour: 20),
            location: ScheduleLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                locationName: "GACI 지부 세미나실"
            ),
            isOnline: false,
            authorMemberId: "201",
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: at(10, hour: 17, minute: 30),
                onTimeEndAt: at(10, hour: 18, minute: 10),
                lateEndAt: at(10, hour: 18, minute: 30)
            ),
            tags: ["네트워킹"],
            participants: [
                ParticipantAttendance(
                    memberId: "202",
                    name: "박안드",
                    nickname: "코틀린",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .pending,
                    isLocationVerified: false,
                    excuseReason: nil
                ),
                ParticipantAttendance(
                    memberId: "203",
                    name: "최웹",
                    nickname: "리액트",
                    profileImageURL: "",
                    schoolId: "3",
                    schoolName: "한성대학교",
                    attendanceStatus: .pending,
                    isLocationVerified: false,
                    excuseReason: nil
                ),
            ]
        )

        return [ongoing, past, upcoming]
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
