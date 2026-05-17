//
//  AttendanceRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation
import Moya

/// 출석체크 Repository 구현체
///
/// `MoyaNetworkAdapter`를 통해 출석 관련 API를 호출하고
/// DTO → Domain 변환을 수행합니다.
final class AttendanceRepository: ChallengerAttendanceRepositoryProtocol,
                                   OperatorAttendanceRepositoryProtocol,
                                   @unchecked Sendable {

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

    // MARK: - 조회

    func fetchMySchedulesForAttendance(
        from: Date,
        to: Date
    ) async throws -> [ScheduleDetailData] {
        let response = try await adapter.request(
            ScheduleV2Router.getMySchedules(
                query: MySchedulesQuery(
                    from: from,
                    to: to,
                    isAttendanceRequired: true
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<[ScheduleDetailDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toScheduleDetailData() }
    }

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo] {
        let response = try await adapter.request(
            ScheduleV2Router.getAttendanceList(
                query: AttendanceListQuery(
                    from: from,
                    to: to,
                    attendanceStatus: attendanceStatus?.serverQueryValue
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<[ScheduleAttendanceInfoDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo {
        let response = try await adapter.request(
            ScheduleV2Router.getAttendanceDetail(
                scheduleId: scheduleId,
                query: AttendanceDetailQuery(
                    attendanceStatus: attendanceStatus?.serverQueryValue
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<ScheduleAttendanceInfoDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    // MARK: - 액션

    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        let body = decisions.map {
            DecideAttendanceItemDTO(
                isApproved: $0.isApproved,
                participantMemberId: $0.participantMemberId,
                reason: $0.reason
            )
        }
        let response = try await adapter.request(
            ScheduleV2Router.decideAttendances(scheduleId: scheduleId, body: body)
        )
        let apiResponse = try decoder.decode(
            APIResponse<[AttendanceDecisionResponseDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func requestAttendance(
        scheduleId: Int,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult {
        let response = try await adapter.request(
            ScheduleV2Router.requestAttendance(
                scheduleId: scheduleId,
                body: RequestAttendanceRequestDTO(
                    latitude: latitude,
                    locationVerified: locationVerified,
                    longitude: longitude
                )
            )
        )
        do {
            let apiResponse = try decoder.decode(
                APIResponse<AttendanceDecisionResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    func submitExcuse(
        scheduleId: Int,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult {
        let response = try await adapter.request(
            ScheduleV2Router.excuseAttendance(
                scheduleId: scheduleId,
                body: ExcuseAttendanceRequestDTO(
                    excuseReason: excuseReason,
                    isVerified: isVerified,
                    latitude: latitude,
                    longitude: longitude
                )
            )
        )
        do {
            let apiResponse = try decoder.decode(
                APIResponse<AttendanceDecisionResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        let request = UpdateScheduleRequestDTO(
            name: nil,
            description: nil,
            startsAt: nil,
            endsAt: nil,
            location: V2LocationDTO(
                latitude: latitude,
                longitude: longitude,
                locationName: locationName
            ),
            participantMemberIds: nil,
            tags: nil,
            attendancePolicy: nil,
            isOnline: nil,
            isAttendanceRequired: nil
        )
        let response = try await adapter.request(
            ScheduleV2Router.patchSchedule(scheduleId: scheduleId, request: request)
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    // MARK: - Private Helper

    /// NetworkError 응답 body에서 서버 에러 메시지 추출
    private static func parseServerError(
        from error: NetworkError
    ) -> Error? {
        guard case .requestFailed(_, let data) = error,
              let data
        else { return nil }

        if let domainError = parseErrorResponse(from: data) {
            return domainError
        }

        guard let json = try? JSONSerialization.jsonObject(
                  with: data
              ) as? [String: Any],
              let message = json["message"] as? String
        else { return nil }
        let code = json["code"] as? String
        return RepositoryError.serverError(
            code: code, message: message
        )
    }

    /// success: false + result: String 형태의 에러 응답 파싱
    private static func parseErrorResponse(
        from data: Data
    ) -> Error? {
        guard let json = try? JSONSerialization.jsonObject(
                  with: data
              ) as? [String: Any],
              json["success"] as? Bool == false
        else { return nil }

        let result = json["result"] as? String ?? ""
        let message = json["message"] as? String

        if result.contains("이미 출석") {
            return DomainError.attendanceAlreadySubmitted
        }

        return RepositoryError.serverError(
            code: json["code"] as? String,
            message: result.isEmpty ? message : result
        )
    }
}
