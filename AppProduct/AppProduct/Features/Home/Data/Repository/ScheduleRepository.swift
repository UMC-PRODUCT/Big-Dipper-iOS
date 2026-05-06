//
//  ScheduleRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation
import Moya

/// Schedule Repository 구현체
///
/// `ScheduleRepositoryProtocol`을 구현하며,
/// `ScheduleRouter`를 통해 일정 관련 API를 호출합니다.
///
/// - SeeAlso: ``ScheduleRepositoryProtocol``, ``ScheduleRouter``
final class ScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    /// Moya 기반 네트워크 어댑터
    private let adapter: MoyaNetworkAdapter

    /// JSON 디코더
    private let decoder: JSONDecoder

    // MARK: - Init

    /// - Parameters:
    ///   - adapter: API 요청을 처리할 네트워크 어댑터
    ///   - decoder: JSON 디코딩에 사용할 디코더 (기본값: JSONDecoder)
    init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Function

    /// 출석 포함 일정을 생성합니다.
    ///
    /// - Parameter schedule: 일정 생성 요청 DTO
    /// - Returns: 생성된 일정 ID (V2 응답의 `result.scheduleId`)
    /// - Throws: 서버 에러 또는 네트워크 에러
    @discardableResult
    func generateSchedule(
        schedule: GenerateScheduleRequetDTO
    ) async throws -> Int {
        let response = try await adapter.request(
            ScheduleV2Router.postSchedule(request: schedule)
        )
        let apiResponse = try decoder.decode(
            APIResponse<Int>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }

    /// 일정을 단순 삭제합니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Throws: 서버 에러 또는 네트워크 에러
    func deleteSchedule(
        scheduleId: Int
    ) async throws {
        let response = try await adapter.request(
            ScheduleV2Router.deleteSchedule(scheduleId: scheduleId)
        )
        if response.data.isEmpty {
            return
        }
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 일정 정보를 부분 수정합니다.
    ///
    /// - Parameters:
    ///   - scheduleId: 수정할 일정 ID
    ///   - schedule: 일정 수정 요청 DTO
    /// - Throws: 서버 에러 또는 네트워크 에러
    func updateSchedule(
        scheduleId: Int,
        schedule: UpdateScheduleRequestDTO
    ) async throws {
        let response = try await adapter.request(
            ScheduleV2Router.patchSchedule(
                scheduleId: scheduleId,
                request: schedule
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 일정과 연결된 출석부를 함께 삭제합니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Throws: 서버 에러 또는 네트워크 에러
    func deleteScheduleWithAttendance(
        scheduleId: Int
    ) async throws {
        let response = try await adapter.request(
            ScheduleRouter.deleteScheduleWithAttendance(
                scheduleId: scheduleId
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }
}
