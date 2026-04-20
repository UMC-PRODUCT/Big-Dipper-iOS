//
//  MockHomeRepository.swift
//  AppProduct
//

import Foundation

// MARK: - MockHomeRepository

/// 게스트 세션 및 프리뷰용 Home Repository Mock 구현체
///
/// 네트워크 없이 정적 데이터를 반환합니다.
final class MockHomeRepository: HomeRepositoryProtocol {

    // MARK: - Function

    func getMyProfile() async throws -> HomeProfileResult {
        try await Task.sleep(for: .milliseconds(200))
        return HomeProfileResult(
            memberId: 1001,
            schoolId: 1,
            schoolName: "UMC 대학교",
            latestChallengerId: 1001,
            latestGisuId: 9,
            chapterId: 1,
            chapterName: "Nova",
            part: .front(type: .ios),
            seasonTypes: [
                .days(82),
                .gens([7, 8, 9])
            ],
            roles: [
                ChallengerRole(
                    challengerId: 1001,
                    gisu: 9,
                    gisuId: 9,
                    roleType: .challenger,
                    responsiblePart: .front(type: .ios),
                    organizationType: .school,
                    organizationId: 1
                )
            ],
            generations: [
                GenerationData(
                    gisuId: 9,
                    gen: 9,
                    penaltyPoint: 1,
                    rewardPoint: 3,
                    pointLogs: [
                        PointLogItem(
                            reason: "우수 워크북",
                            date: "04.10",
                            point: 2,
                            isReward: true
                        ),
                        PointLogItem(
                            reason: "지각",
                            date: "04.05",
                            point: -1,
                            isReward: false
                        ),
                        PointLogItem(
                            reason: "스터디 발표",
                            date: "03.28",
                            point: 1,
                            isReward: true
                        )
                    ],
                    penaltyLogs: [
                        PenaltyInfoItem(
                            reason: "지각",
                            date: "2026.04.05",
                            penaltyPoint: 1
                        )
                    ]
                ),
                GenerationData(
                    gisuId: 8,
                    gen: 8,
                    penaltyPoint: 0,
                    rewardPoint: 2,
                    pointLogs: [],
                    penaltyLogs: []
                )
            ],
            generationOrganizations: [
                GenerationOrganizationContext(
                    gen: 9,
                    chapterId: 1,
                    chapterName: "Nova",
                    schoolId: 1,
                    schoolName: "UMC 대학교"
                )
            ]
        )
    }

    func getSchedules(
        year: Int,
        month: Int
    ) async throws -> [Date: [ScheduleData]] {
        try await Task.sleep(for: .milliseconds(200))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ServerDateTimeConverter.kstTimeZone

        let today = calendar.startOfDay(for: Date())
        let inTwoDays = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let inFiveDays = calendar.date(byAdding: .day, value: 5, to: today) ?? today

        return [
            today: [
                ScheduleData(
                    scheduleId: 1,
                    title: "9기 해커톤 OT",
                    startsAt: today.addingTimeInterval(60 * 60 * 14),
                    endsAt: today.addingTimeInterval(60 * 60 * 16),
                    status: "참여 예정",
                    dDay: 0
                )
            ],
            inTwoDays: [
                ScheduleData(
                    scheduleId: 2,
                    title: "iOS 파트 스터디",
                    startsAt: inTwoDays.addingTimeInterval(60 * 60 * 19),
                    endsAt: inTwoDays.addingTimeInterval(60 * 60 * 21),
                    status: "참여 예정",
                    dDay: 2
                )
            ],
            inFiveDays: [
                ScheduleData(
                    scheduleId: 3,
                    title: "UMCON 컨퍼런스",
                    startsAt: inFiveDays.addingTimeInterval(60 * 60 * 10),
                    endsAt: inFiveDays.addingTimeInterval(60 * 60 * 18),
                    status: "참여 예정",
                    dDay: 5
                )
            ]
        ]
    }

    func getScheduleDetail(
        scheduleId: Int
    ) async throws -> ScheduleDetailData {
        throw DomainError.custom(message: "게스트 세션에서는 일정 상세를 조회할 수 없습니다.")
    }

    func getRecentNotices(
        query: NoticeListRequestDTO
    ) async throws -> [RecentNoticeData] {
        try await Task.sleep(for: .milliseconds(200))
        let now = Date()
        return [
            RecentNoticeData(
                noticeId: 1,
                category: .operationsTeam,
                title: "9th UMC Hackathon 모집 신청 안내",
                createdAt: now
            ),
            RecentNoticeData(
                noticeId: 2,
                category: .operationsTeam,
                title: "🗣️ 9th UMC 동아리 연합 컨퍼런스 신청 모집 안내",
                createdAt: now.addingTimeInterval(-60 * 60 * 24)
            ),
            RecentNoticeData(
                noticeId: 3,
                category: .univ,
                title: "[투표] 9기 기말고사 뒤풀이 메뉴 선정 안내",
                createdAt: now.addingTimeInterval(-60 * 60 * 48)
            )
        ]
    }

    func registerFCMToken(fcmToken: String) async throws {}
}

// MARK: - MockScheduleRepository

/// 게스트 세션 및 프리뷰용 Schedule Repository Mock 구현체
final class MockScheduleRepository: ScheduleRepositoryProtocol {

    func generateSchedule(schedule: GenerateScheduleRequetDTO) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func updateSchedule(scheduleId: Int, schedule: UpdateScheduleRequestDTO) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func deleteScheduleWithAttendance(scheduleId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}

// MARK: - MockChallengerGenRepository

/// 게스트 세션 및 프리뷰용 ChallengerGen Repository Mock 구현체
final class MockChallengerGenRepository: ChallengerGenRepositoryProtocol {

    private var pairs: [(gen: Int, gisuId: Int)] = [
        (gen: 7, gisuId: 7),
        (gen: 8, gisuId: 8),
        (gen: 9, gisuId: 9)
    ]

    func replaceMappings(_ pairs: [(gen: Int, gisuId: Int)]) throws {
        if !pairs.isEmpty {
            self.pairs = pairs
        }
    }

    func fetchGenGisuIdPairs() throws -> [(gen: Int, gisuId: Int)] {
        pairs
    }
}

// MARK: - MockChallengerSearchRepository

/// 게스트 세션 및 프리뷰용 ChallengerSearch Repository Mock 구현체
final class MockChallengerSearchRepository: ChallengerSearchRepositoryProtocol {

    func searchChallengers(
        query: ChallengerSearchRequestDTO
    ) async throws -> ChallengerSearchResponseDTO {
        let json = """
        {"cursor":{"content":[],"nextCursor":null,"hasNext":false}}
        """
        return try JSONDecoder().decode(
            ChallengerSearchResponseDTO.self,
            from: Data(json.utf8)
        )
    }
}
