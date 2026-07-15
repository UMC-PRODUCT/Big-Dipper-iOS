//
//  ScheduleRepository.swift
//  HomeData
//
//  Created by euijjang97 on 7/11/26.
//

import CoreNetwork
import Foundation
import HomeDomain
import UMCFoundation

/// 홈 일정 캘린더 조회 Repository 구현체
public final class ScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any HomeNetworkRequesting

    // MARK: - Init

    /// 운영(DI) 진입점.
    public convenience init(adapter: MoyaNetworkAdapter) {
        self.init(networkRequesting: adapter)
    }

    /// 네트워크 추상화를 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(networkRequesting: any HomeNetworkRequesting) {
        self.networkRequesting = networkRequesting
    }

    // MARK: - Function

    /// 기간 내 일정을 조회하고 KST 자정 기준 날짜별로 그룹핑하여 반환한다.
    public func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        let response = try await networkRequesting.request(
            ScheduleV2Router.getMySchedules(
                query: MySchedulesQuery(
                    from: from,
                    to: to,
                    isAttendanceRequired: isAttendanceRequired
                )
            )
        )

        let schedules: [ScheduleDetailData]
        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<[ScheduleDetailDTO]>.self,
                from: response.data
            )
            schedules = try apiResponse.unwrap().map { $0.toDomain() }
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[ScheduleRepository] fetchMySchedules decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }

        let calendar = Calendar.kstGregorian
        return Dictionary(grouping: schedules) { calendar.startOfDay(for: $0.startsAt) }
    }
}
