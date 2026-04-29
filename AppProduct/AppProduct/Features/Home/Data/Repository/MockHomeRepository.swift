//
//  MockHomeRepository.swift
//  AppProduct
//

import Foundation

// MARK: - MockHomeRepository

/// 프리뷰 및 테스트용 Home Repository Mock 구현체
///
/// 네트워크 없이 정적 데이터를 반환합니다.
final class MockHomeRepository: HomeRepositoryProtocol {

    // MARK: - Function

    func getMyProfile() async throws -> HomeProfileResult {
        HomeProfileResult(
            memberId: 0,
            schoolId: 0,
            schoolName: "UMC 대학교",
            latestChallengerId: nil,
            latestGisuId: nil,
            chapterId: nil,
            chapterName: "UMC",
            part: nil,
            seasonTypes: [.days(0)],
            roles: [],
            generations: []
        )
    }

    func getSchedules(
        year: Int,
        month: Int
    ) async throws -> [Date: [ScheduleData]] {
        [:]
    }

    func getScheduleDetail(
        scheduleId: Int
    ) async throws -> ScheduleDetailData {
        throw DomainError.custom(message: "Mock 환경에서는 일정 상세를 조회할 수 없습니다.")
    }

    func getRecentNotices(
        query: NoticeListRequestDTO
    ) async throws -> [RecentNoticeData] {
        []
    }

    func registerFCMToken(fcmToken: String) async throws {}
}

// MARK: - MockScheduleRepository

/// 프리뷰 및 테스트용 Schedule Repository Mock 구현체
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

/// 프리뷰 및 테스트용 ChallengerGen Repository Mock 구현체
final class MockChallengerGenRepository: ChallengerGenRepositoryProtocol {

    func replaceMappings(_ pairs: [(gen: Int, gisuId: Int)]) throws {}

    func fetchGenGisuIdPairs() throws -> [(gen: Int, gisuId: Int)] {
        []
    }
}

// MARK: - MockChallengerSearchRepository

/// 프리뷰 및 테스트용 ChallengerSearch Repository Mock 구현체
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
