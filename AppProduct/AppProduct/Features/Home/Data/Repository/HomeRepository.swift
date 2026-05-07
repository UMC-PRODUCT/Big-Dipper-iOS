//
//  HomeRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation
import Moya

/// Home Repository 구현체
final class HomeRepository: HomeRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Function

    /// 내 프로필 조회 (기수 카드 + 역할 정보)
    func getMyProfile() async throws -> HomeProfileResult {
        let response = try await adapter.request(HomeRouter.getGen)
        let apiResponse = try decoder.decode(
            APIResponse<MyProfileResponseDTO>.self,
            from: response.data
        )
        let profile = try apiResponse.unwrap()
        let seasonTypes = try await makeSeasonTypes(profile: profile)
        return profile.toHomeProfileResult(seasonTypes: seasonTypes)
    }

    /// 기간 내 일정을 조회하고 KST 자정 기준 날짜별로 그룹핑하여 반환합니다.
    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        let response = try await adapter.request(
            ScheduleV2Router.getMySchedules(
                query: MySchedulesQuery(
                    from: from,
                    to: to,
                    isAttendanceRequired: isAttendanceRequired
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<[ScheduleDetailDTO]>.self,
            from: response.data
        )
        let schedules = try apiResponse.unwrap().map {
            $0.toScheduleDetailData()
        }
        let calendar = Calendar.kstGregorian
        return Dictionary(grouping: schedules) {
            calendar.startOfDay(for: $0.startsAt)
        }
    }

    /// 일정 상세를 조회합니다.
    func getScheduleDetail(scheduleId: Int) async throws -> ScheduleDetailData {
        let response = try await adapter.request(
            ScheduleV2Router.getScheduleDetail(scheduleId: scheduleId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<ScheduleDetailDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toScheduleDetailData()
    }

    /// 최근 공지사항을 조회합니다 (최대 5개).
    func getRecentNotices(
        query: NoticeListRequestDTO
    ) async throws -> [RecentNoticeData] {
        let response = try await adapter.request(
            HomeRouter.getNoticeRecent(query: query)
        )
        let apiResponse = try decoder.decode(
            APIResponse<PageDTO<NoticeListResponseDTO>>.self,
            from: response.data
        )
        let page = try apiResponse.unwrap()
        return Array(page.content.prefix(5).map { $0.toRecentNoticeData() })
    }

    /// FCM 토큰을 서버에 등록/갱신합니다.
    func registerFCMToken(
        fcmToken: String
    ) async throws {
        let response = try await adapter.request(
            HomeRouter.putFCMToken(
                request: RegisterFCMTokenRequestDTO(fcmToken: fcmToken)
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

}

// MARK: - Private Helpers

private extension HomeRepository {
    func makeSeasonTypes(profile: MyProfileResponseDTO) async throws -> [SeasonType] {
        let records = profile.challengerRecords ?? []
        let generations = Set(profile.roles.map(\.gisu) + records.map(\.gisu))
            .filter { $0 > 0 }
            .sorted()
        let recordGisuIds = Set(records.map(\.gisuId))
            .filter { $0 > 0 }
        let roleGisuIds = Set(profile.roles.map(\.gisuId))
            .filter { $0 > 0 }
        let targetGisuIds = recordGisuIds.isEmpty ? roleGisuIds : recordGisuIds

        guard !targetGisuIds.isEmpty else {
            return [
                .days(0),
                .gens(generations)
            ]
        }

        var earliestStartDate: Date?
        try await withThrowingTaskGroup(of: Date?.self) { group in
            for gisuId in targetGisuIds {
                group.addTask {
                    try await self.fetchSeasonStartDate(gisuId: gisuId)
                }
            }

            for try await startDate in group {
                guard let startDate else { continue }
                if let currentEarliest = earliestStartDate {
                    earliestStartDate = min(currentEarliest, startDate)
                } else {
                    earliestStartDate = startDate
                }
            }
        }

        let activityDays = earliestStartDate.map { calculateActivityDays(from: $0) } ?? 0

        return [
            .days(activityDays),
            .gens(generations)
        ]
    }

    func fetchSeasonStartDate(gisuId: Int) async throws -> Date? {
        let response = try await adapter.request(
            HomeRouter.getGisuDetail(gisuId: gisuId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<GisuDetailDTO>.self,
            from: response.data
        )
        let gisuDetail = try apiResponse.unwrap()

        guard gisuDetail.startAt != .distantPast else {
            return nil
        }

        return gisuDetail.startAt
    }

    func calculateActivityDays(from startDate: Date, to endDate: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ServerDateTimeConverter.kstTimeZone

        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        guard start <= end else {
            return 0
        }

        let elapsedDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(elapsedDays + 1, 0)
    }
}
