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

    func getAttendanceDetail(
        recordId: Int
    ) async throws -> AttendanceRecord {
        let response = try await adapter.request(
            AttendanceRouter.getDetail(recordId: recordId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<AttendanceDetailDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    func getPendingAttendances(
        scheduleId: Int
    ) async throws -> [PendingAttendanceRecord] {
        let response = try await adapter.request(
            AttendanceRouter.getPending(scheduleId: scheduleId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<[PendingAttendanceDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func getAllPendingAttendances(
    ) async throws -> [Int: [PendingAttendanceRecord]] {
        let response = try await adapter.request(
            AttendanceRouter.getAllPending
        )
        let apiResponse = try decoder.decode(
            APIResponse<[SchedulePendingGroupDTO]>.self,
            from: response.data
        )
        let groups = try apiResponse.unwrap()
        var result: [Int: [PendingAttendanceRecord]] = [:]
        for group in groups {
            let (scheduleId, records) = group.toDomainEntry()
            result[scheduleId] = records
        }
        return result
    }

    func getMyHistory() async throws -> [AttendanceHistoryItem] {
        let response = try await adapter.request(
            AttendanceRouter.getMyHistory
        )
        let apiResponse = try decoder.decode(
            APIResponse<[AttendanceHistoryItemDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func getChallengerHistory(
        challengerId: Int
    ) async throws -> [AttendanceHistoryItem] {
        let response = try await adapter.request(
            AttendanceRouter.getChallengerHistory(
                challengerId: challengerId
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<[AttendanceHistoryItemDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func getAvailableSchedules(
    ) async throws -> [AvailableAttendanceSchedule] {
        let response = try await adapter.request(
            AttendanceRouter.getAvailable
        )
        let apiResponse = try decoder.decode(
            APIResponse<[AvailableScheduleDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func getScheduleStats(
    ) async throws -> [ScheduleAttendanceStats] {
        let response = try await adapter.request(
            ScheduleRouter.getScheduleList
        )
        let apiResponse = try decoder.decode(
            APIResponse<[ScheduleListDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo] {
        let response = try await adapter.request(
            ScheduleV2Router.getAttendanceList(
                from: from,
                to: to,
                attendanceStatus: attendanceStatus?.serverQueryValue
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
                attendanceStatus: attendanceStatus?.serverQueryValue
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<ScheduleAttendanceInfoDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    // MARK: - 액션

    func approveAttendance(recordId: Int) async throws {
        let response = try await adapter.request(
            AttendanceRouter.approve(recordId: recordId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    func rejectAttendance(recordId: Int) async throws {
        let response = try await adapter.request(
            AttendanceRouter.reject(recordId: recordId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        #if DEBUG
        let payload: [String: Any] = [
            "locationName": locationName,
            "latitude": latitude,
            "longitude": longitude
        ]
        print("===== UPDATE SCHEDULE LOCATION REQUEST =====")
        print("scheduleId:", scheduleId)
        print("locationName:", locationName)
        print("latitude:", latitude, "isFinite:", latitude.isFinite)
        print("longitude:", longitude, "isFinite:", longitude.isFinite)
        print("isValidJSONObject:", JSONSerialization.isValidJSONObject(payload))
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            print("payload JSON:\n\(json)")
        } else {
            print("payload JSON serialization failed before request")
        }
        print("===========================================")
        #endif

        let response = try await adapter.request(
            AttendanceRouter.patchScheduleLocation(
                scheduleId: scheduleId,
                body: ScheduleLocationUpdateRequestDTO(
                    locationName: locationName,
                    latitude: latitude,
                    longitude: longitude
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    func checkAttendance(
        request: AttendanceCheckRequestDTO
    ) async throws -> Int {
        do {
            let response = try await adapter.request(
                AttendanceRouter.check(body: request)
            )
            let apiResponse = try decoder.decode(
                APIResponse<String>.self,
                from: response.data
            )
            let result = try apiResponse.unwrap()
            guard let id = Int(result) else {
                throw Self.parseErrorResponse(
                    from: response.data
                ) ?? RepositoryError.serverError(
                    code: nil, message: result
                )
            }
            return id
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    func submitReason(
        request: AttendanceReasonRequestDTO
    ) async throws -> Int {
        do {
            let response = try await adapter.request(
                AttendanceRouter.submitReason(body: request)
            )
            let apiResponse = try decoder.decode(
                APIResponse<String>.self,
                from: response.data
            )
            let result = try apiResponse.unwrap()
            guard let id = Int(result) else {
                throw Self.parseErrorResponse(
                    from: response.data
                ) ?? RepositoryError.serverError(
                    code: nil, message: result
                )
            }
            return id
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    // MARK: - Private Helper

    /// success: false + result: String 형태의 에러 응답 파싱
    ///
    /// 서버가 `APIResponse<Int>` 대신 `result: "이미 출석 체크가 완료되었습니다"`
    /// 같은 String을 반환하는 경우 DomainError로 매핑합니다.
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

        // 서버 에러 메시지 → DomainError 매핑
        if result.contains("이미 출석") {
            return DomainError.attendanceAlreadySubmitted
        }

        return RepositoryError.serverError(
            code: json["code"] as? String,
            message: result.isEmpty ? message : result
        )
    }

    /// NetworkError 응답 body에서 서버 에러 메시지 추출
    private static func parseServerError(
        from error: NetworkError
    ) -> Error? {
        guard case .requestFailed(_, let data) = error,
              let data
        else { return nil }

        // DomainError 매핑 먼저 시도
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
}
