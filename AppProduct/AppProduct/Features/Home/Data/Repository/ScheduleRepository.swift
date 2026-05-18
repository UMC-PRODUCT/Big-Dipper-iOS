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
/// `ScheduleV2Router`를 통해 일정 관련 API를 호출합니다.
///
/// - SeeAlso: ``ScheduleRepositoryProtocol``, ``ScheduleV2Router``
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
            APIResponse<String>.self,
            from: response.data
        )
        let resultString = try apiResponse.unwrap()
        guard let scheduleId = Int(resultString) else {
            throw RepositoryError.serverError(
                code: apiResponse.code,
                message: "Invalid schedule ID: \(resultString)"
            )
        }
        return scheduleId
    }

    /// 일정을 단순 삭제합니다.
    ///
    /// 서버는 출석 기록이 1건이라도 있는 일정에 대해 일반 DELETE 를 거부합니다 (FORCE_DELETE 만 허용).
    /// 이 경우 응답 메시지를 파싱해 ``DomainError/scheduleHasAttendanceRecords`` 로 변환합니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Throws: ``DomainError/scheduleHasAttendanceRecords`` / 서버 에러 / 네트워크 에러
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
        do {
            try apiResponse.validateSuccess()
        } catch let error as RepositoryError {
            throw Self.mapScheduleDeleteError(error)
        }
    }

    /// 일정 삭제 실패 메시지에서 출석 기록 존재 케이스를 감지해 도메인 에러로 변환합니다.
    ///
    /// 서버 메시지 또는 에러 코드를 기반으로 ``DomainError/scheduleHasAttendanceRecords`` 로 매핑합니다.
    private static func mapScheduleDeleteError(_ error: RepositoryError) -> Error {
        guard case .serverError(let code, let message) = error else { return error }
        let combined = "\(code ?? "") \(message ?? "")"
        if combined.contains("출석 기록") || combined.contains("출석 데이터") || combined.contains("출석") && combined.contains("삭제") {
            return DomainError.scheduleHasAttendanceRecords
        }
        return error
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
    /// V1 통합 삭제 엔드포인트 제거에 따라 V2 단순 삭제 엔드포인트로 통합되었습니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Throws: 서버 에러 또는 네트워크 에러
    func deleteScheduleWithAttendance(
        scheduleId: Int
    ) async throws {
        try await deleteSchedule(scheduleId: scheduleId)
    }

    /// 출석 기록이 있는 일정을 강제 삭제합니다.
    ///
    /// 서버 권한 정책상 일정 기수의 SUPER_ADMIN 만 호출할 수 있으며, 그 외 사용자는 403 으로 반려됩니다.
    ///
    /// - Parameter scheduleId: 강제 삭제할 일정 ID
    /// - Throws: 서버 에러 또는 네트워크 에러
    func forceDeleteSchedule(
        scheduleId: Int
    ) async throws {
        let response = try await adapter.request(
            ScheduleV2Router.forceDeleteSchedule(scheduleId: scheduleId)
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
}
